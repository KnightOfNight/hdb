

use strict;
use warnings;
use File::Temp;


package System;


sub my_system {
	my @cmd = @_;
	my $cmd_ret;
	my $return;

	system (@cmd);
	$cmd_ret = $?;

	if ($cmd_ret == -1) {
		printf ("my_system(): unable to execute command: %s\n", $!);
		return (-1);
	} elsif ($cmd_ret & 127) {
		printf ("my_system(): child died with signal %d, %s coredump\n", ($cmd_ret & 127), ($cmd_ret & 128) ? 'with' : 'without');
		return (-1);
	} else {
		$cmd_ret = $cmd_ret >> 8;

		if ($cmd_ret) {
			return ($cmd_ret);
		} else {
			return (0);
		}
	}

	return ($return);
}


1;
