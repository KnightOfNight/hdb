

use strict;
use warnings;
use File::Temp;


package System;


sub exec {
	my @cmd = @_;
	my $cmd_ret;

	system (@cmd);
	$cmd_ret = $?;

	if ($cmd_ret == -1) {
		printf ("System::exec() unable to execute command: %s\n", $!);
		return (-1);
	} elsif ($cmd_ret & 127) {
		printf ("System::exec() child died with signal %d, %s coredump\n", ($cmd_ret & 127), ($cmd_ret & 128) ? 'with' : 'without');
		return (-1);
	} else {
		$cmd_ret = $cmd_ret >> 8;

		if ($cmd_ret) {
			return ($cmd_ret);
		} else {
			return (0);
		}
	}
}


1;
