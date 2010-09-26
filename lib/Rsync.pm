

use lib "/usr/local/hdb/lib";


use strict;
use warnings;
use System;
use File::Temp;


package Rsync;


my %OPTIONS = (	"destination"	=> "",
				"verbose"		=> 0,
				"debug"			=> 0,
				"rsync_cmd"		=> "/usr/bin/rsync",
				"rsync_opts"	=> "-av --numeric-ids --delete-after"
);


sub new {
	my @args = @_;
	my $self = {};

	my $class = $args[0];
	my ($options) = $args[1];

	my $verbose = 0;
	my $debug = 0;
	my $cmd;

	if ($options->{"verbose"}) {
		$self->{"verbose"} = $verbose;
		$verbose = 1;
	}

	if ($options->{"debug"}) {
		$self->{"debug"} = $debug;
		$debug = 1;
	}

	for my $option (sort (keys (%OPTIONS))) {
		if (my $value = $options->{$option}) {
			$self->{$option} = $value;
			printf ("DEBUG: %s = '%s'\n", $option, $value) if $self->{"debug"};
		} else {
			$self->{$option} = $OPTIONS{$option};
			$options->{$option} = $OPTIONS{$option};
			printf ("DEBUG: %s = default ('%s')\n", $option, $OPTIONS{$option}) if $self->{"debug"};
		}
	}


	if ( $options->{"destination"} ) {

		System::my_system("date +%s > /tmp/.hdb_time");

		$cmd = sprintf("scp /tmp/.hdb_time %s/", $options->{"destination"});

		printf ("DEBUG: cmd = '%s'\n", $cmd) if $self->{"debug"};

		if (System::my_system ($cmd)) {
			die("Unable to exec '$cmd'.\n");
		}

	} else {

		die ("ERROR: no destination specified\n");

	}

	bless ($self, $class);

	return ($self);
}


sub setoption ($$$) {
	my $self = $_[0];

	my $option = $_[1];
	my $value = $_[2];
	my $add = $_[3];

	if (! grep (/^$option$/, sort (keys (%OPTIONS)))) {
		printf ("ERROR: Rsync::set_option: invalid option '%s'\n", $option);
		exit (-1);
	}

	if (! $value) {
		$value = $OPTIONS{$option};
	}

	printf ("DEBUG: setting option '%s' to '%s'\n", $option, $value) if $self->{"debug"};

	if ($add) {
		$self->{$option} = $self->{$option} . " " . $value;
	} else {
		$self->{$option} = $value;
	}
}


sub go ($@$) {
	my $self = $_[0];
	my @source = @{$_[1]};
	my $dest = $_[2];

	for (my $i = 0; $source[$i]; $i++) {
		if ($source[$i] =~ / /) {
			$source[$i] = "\"" . $source[$i] . "\"";
		}
	}

	my $source = join (" ", sort (@source));

	if (! $self->{"stdout"}) {
		$self->{"stdout"} = File::Temp::mktemp ("/tmp/rsync.out.XXXX");
	}

	$self->{"stderr"} = $self->{"stdout"};
	$self->{"stderr"} =~ s/out/err/;


	my $cmd = sprintf ("%s %s %s %s > %s 2> %s",
		$self->{"rsync_cmd"}, $self->{"rsync_opts"},
		$source, $dest, $self->{"stdout"}, $self->{"stderr"});

	printf ("\n");
	printf ("source(s): %s\n", $source);
	printf ("destination: %s\n", $dest);

	printf ("\n(debug) cmd: %s\n", $cmd) if ($self->{"debug"});

	my $time_start = time ();
	printf ("\nrsync started: %s\n", scalar (localtime ($time_start)));

	system ($cmd);
	my $ret = $?;

	if ($ret == -1) {
		printf ("\nERROR: failed to execute rsync\n");
		$self->print_errors ();
		return (0);
	} elsif ($ret & 127) {
		printf ("\nERROR: rsync died with signal %d, %s core dump\n", ($? & 127), ($? & 128) ? "with" : "without");
		$self->print_errors ();
		return (0);
	} elsif ($ret) {
		printf ("\nWARNING: rsync exited with %d\n", $ret);
		$self->print_errors ();
		return (0);
	}

	my $time_stop = time ();
	printf ("\nrsync ended: %s\n", scalar (localtime ($time_stop)));

	my $time_diff = $time_stop - $time_start;

	if (! $time_diff) {
		$time_diff++;
	}

	my $hours = int ($time_diff / 3600);
	my $mins = int (($time_diff % 3600) / 60);
	my $secs = int (($time_diff % 3600) % 60);

	printf ("\ntime elapsed: %.2d:%.2d:%.2d\n", $hours, $mins, $secs);


	my ($fh);
	open ($fh, "<", $self->{"stdout"});
	my (@stdout) = <$fh>;
	close ($fh);

	chomp (@stdout);

	shift (@stdout);
	my ($summ2) = pop (@stdout);
	my ($summ1) = pop (@stdout);

	my (@copied) = grep (!/^deleting/, @stdout);
	my (@deleted) = grep (/^deleting/, @stdout);

	for (my $i = 0; $deleted[$i]; $i++) {
		$deleted[$i] =~ s/^deleted //;
	}

	printf ("\n%d files copied\n", scalar (grep (/[^\/]$/, @copied)));
	map { printf ("\t%s\n", $_) } grep (/[^\/]$/, @copied) if $self->{"verbose"};

	printf ("\n%d dirs copied\n", scalar (grep (/\/$/, @copied)));
	map { printf ("\t%s\n", $_) } grep (/\/$/, @copied) if $self->{"verbose"};

	printf ("\n%d files deleted\n", scalar (grep (/[^\/]$/, @deleted)));
	map { printf ("\t%s\n", $_) } grep (/[^\/]$/, @deleted) if $self->{"verbose"};

	printf ("\n%d dirs deleted\n", scalar (grep (/\/$/, @deleted)));
	map { printf ("\t%s\n", $_) } grep (/\/$/, @deleted) if $self->{"verbose"};

	printf ("\n%s\n%s\n", $summ1, $summ2);


	return (1);
}


sub print_errors {
	my $self = $_[0];

	my $stderr = $self->{"stderr"};

	if (! -s $stderr) {
		return (0);
	}

	my ($fh);

	open ($fh, "<", $stderr);
	my (@stderr) = <$fh>;
	close ($fh);

	chomp (@stderr);

	printf ("\nrsync stderr follows...\n");

	foreach my $line (@stderr) {
		printf ("\t%s\n", $line) if ($line =~ /^.+$/);
	}
}


sub cleanup () {
	my $self = $_[0];

	unlink ($self->{"stdout"});
	$self->{"stdout"} = "";

	unlink ($self->{"stderr"});
	$self->{"stderr"} = "";
}


1;
