use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
        if ($Config{'osname'} eq 'VMS' or
            $Config{'osname'} eq 'OS2');  # "case-forgiving"
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w

!GROK!THIS!

print OUT <<'!NO!SUBS!';
=head1 NAME

timed-process - Run background process for limited amount of time

=head1 SYNOPSIS

    timed-process timeout path_to_program [<arg>...]

=head1 DESCRIPTION

This script runs a program for a specified amount of time and if it
doesn't finish, it kills the process.  This script requires the
complete pathname to the program to run and any optional arguments.
The program returns the exit status of the executed program.

=cut

use strict;
use Proc::Generic qw(timeout_system);
use Getopt::Long;

$0 =~ s:.*/::;

sub usage {
  print <<END;
Usage: $0 timeout path_to_program [<arg>...]

This script runs a program for a specified amount of time and if it
doesn't finish, it kills the process.  This script requires the
complete pathname to the program to run and any optional arguments.
The program returns the exit status of the executed program.
END
  exit 1;
}

@ARGV > 1 or usage;

print "@ARGV\n";

exit timeout_system(@ARGV);

!NO!SUBS!
