

use lib "/usr/local/hdb/lib";


use strict;
use warnings;
use System;
use File::Temp;
use File::Basename;


package Rsync;


sub new {
	my @args = @_;
	my $class = $args[0];
	my ($options) = $args[1];
	my $self = {};


	if ( $options->{"rsync_cmd"} ) {
		$self->{"rsync_cmd"} = $options->{"rsync_cmd"};
	} else {
		$self->{"rsync_cmd"} = "/usr/bin/rsync";
	}

	if ( $options->{"rsync_opts"} ) {
		$self->{"rsync_opts"} = $options->{"rsync_opts"};
		$self->{"rsync_opts"} .= " --verbose";
	} else {
		$self->{"rsync_opts"} = "-av --numeric-ids --delete-after";
	}

	if ( $options->{"scp_opts"} ) {
		$self->{"scp_opts"} = $options->{"scp_opts"};
	} else {
		$self->{"scp_opts"} = "";
	}

	if ( $options->{"destination"} ) {
		$self->{"destination"} = $options->{"destination"};
	} else {
		die("Rsync::new() destination must be specified\n");
	}

	if ($options->{"test"}) {
		$self->{"rsync_opts"} .= " --dry-run";
		$self->{"test"} = 1;
	} else {
		$self->{"test"} = 0;
	}

	if ($options->{"debug"}) {
		$self->{"debug"} = 1;
	} else {
		$self->{"debug"} = 0;
	}


	# Tag the remote filesystem.  This verifies SSH and the ability to write to the destination.
	my $cmd;

	$cmd = "date +%s > /tmp/.hdb_time";
	printf ("DEBUG: cmd = '%s'\n", $cmd) if $self->{"debug"};

	if (System::exec($cmd)) {
		die("Rsync::new() unable to run '$cmd'\n");
	}

	$cmd = sprintf("scp %s -q /tmp/.hdb_time %s/", $self->{"scp_opts"}, $self->{"destination"});
	printf ("DEBUG: cmd = '%s'\n", $cmd) if $self->{"debug"};

	if (System::exec($cmd)) {
		die("Rsync::new() unable to run '$cmd'\n");
	}

	printf ("Successfully tagged destination directory.  It is writable and can be used.\n");


	bless($self, $class);


	return($self);
}


sub go ($$) {
	my $self = $_[0];
	my $source = $_[1];


	my $destination = $self->{"destination"};


    my $dirname = File::Basename::dirname($source);


    if ($dirname ne "/") {
        $destination .= $dirname;
    }


	if ($source =~ / /) {
		$source = "\"" . $source . "\"";
	}


	if (! $self->{"stdout"}) {
		$self->{"stdout"} = File::Temp::mktemp ("/tmp/rsync.out.XXXX");
	}

	$self->{"stderr"} = $self->{"stdout"};
	$self->{"stderr"} =~ s/out/err/;


	my $cmd = sprintf ("%s %s %s %s 2>%s > %s",
		$self->{"rsync_cmd"}, $self->{"rsync_opts"},
		$source, $destination, $self->{"stderr"}, $self->{"stdout"});
	printf ("DEBUG: cmd = '%s'\n", $cmd) if $self->{"debug"};


	printf ("======================================================================\n");
	printf ("TEST MODE ON - NOTHING WILL BE MODIFIED IN ANY WAY\n\n") if $self->{"test"};

	printf ("%s  ===>>>  %s\n", $source, $destination);
	printf ("\n");
	printf ("using options: %s\n", $self->{"rsync_opts"});

	my $time_start = time ();
	printf ("\n");
	printf ("starting @ %s (%d)\n", scalar (localtime ($time_start)), $time_start);

	my $ret = System::exec($cmd);

#	if ( $ret == -1 ) {
#		die("Rsync::go() unable to execute rsync\n");
#	} elsif ( ( $ret > 0 ) && ( $ret != 24 ) ) {
#		printf("Rsync::go() warning: rsync returned %d\n", $ret);
#		$self->errors();
#	} else {
#		$self->report();
#	}

	if ( $ret == -1 ) {
		die("Rsync::go() unable to execute rsync\n");
	} elsif ( ( $ret == 0 ) || ( $ret == 24 ) ) {
		$ret = 0;
		$self->report();
	} else {
		$self->errors();
	}

	my $time_stop = time ();
	my $time_diff = $time_stop - $time_start;

	printf ("\n");
	printf ("finished @ %s (%d)\n", scalar (localtime ($time_stop)), $time_stop);

	printf ("\n");
	if ($time_diff) {
		my $hours = int ($time_diff / 3600);
		my $mins = int (($time_diff % 3600) / 60);
		my $secs = int (($time_diff % 3600) % 60);
		printf ("time elapsed: %.2d:%.2d:%.2d\n", $hours, $mins, $secs);
	} else {
		printf ("time elapsed: <1s\n");
	}
	printf ("======================================================================\n");

	unlink($self->{"stdout"});
	unlink($self->{"stderr"});

	$self->{"stdout"} = "";
	$self->{"stderr"} = "";

	return($ret);
}


sub errors () {
	my $self = $_[0];

	my $stderr = $self->{"stderr"};

	if ( ! -s $stderr ) {
		return;
	}

	open (my $fh, "<", $self->{"stderr"}) || die ("Rsync::error() unable to open stderr file '$stderr'\n");
	my @stderr = <$fh>;
	close ($fh);

	chomp (@stderr);

	@stderr = grep ( /^.+$/ , @stderr );

	printf ("---STDERR---\n");
	map { printf("%s\n", $_) } @stderr;
	printf ("---STDERR---\n");
}


sub report () {
	my $self = $_[0];

	my $stdout = $self->{"stdout"};

	open (my $fh, "<", $self->{"stdout"}) || die ("Rsync::report() unable to open stdout file '$stdout'\n");
	my @stdout = <$fh>;
	close ($fh);

	chomp (@stdout);

	@stdout = grep ( /^.+$/ , @stdout );

	shift (@stdout);
	my ($summ2) = pop (@stdout);
	my ($summ1) = pop (@stdout);

	my (@copied) = grep (!/^deleting/, @stdout);
	my (@deleted) = grep (/^deleting/, @stdout);

	for (my $i = 0; $deleted[$i]; $i++) {
		$deleted[$i] =~ s/^deleted //;
	}

	printf ("\n");
	if ( scalar(@stdout) ) {
		printf ("%d files copied, ", scalar (grep (/[^\/]$/, @copied)));
		printf ("%d files deleted\n", scalar (grep (/[^\/]$/, @deleted)));
		printf ("%d dirs copied, ", scalar (grep (/\/$/, @copied)));
		printf ("%d dirs deleted\n", scalar (grep (/\/$/, @deleted)));
	} else {
		printf ("nothing copied, nothing deleted\n");
	}

	printf ("\n");
	printf ("%s\n%s\n", $summ1, $summ2);

	if ( scalar(@stdout) ) {
		printf ("\n");
		printf ("---FILE LIST---\n");
		map { printf("%s\n", $_) } @stdout;
		printf ("---FILE LIST---\n");
	}
}


1;
