# This -*- perl -*- script writes the Makefile for this package.

require 5.004_04;
use strict;

#--- Configuration section ---

my @programs_to_install = qw(timed-process);

#--- End Configuration - You should not have to change anything below this line

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
use vars qw($opt_n);
unless (getopts('n')) {
  die "Usage: $0 [-n]\n";
}
@programs_to_install = () if $opt_n;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME		=> 'Proc::Background',
  VERSION_FROM	=> 'lib/Proc/Background.pm',
  PL_FILES	=> { map {("bin/$_.PL" => "bin/$_")} @programs_to_install },
  EXE_FILES	=> [map {"bin/$_"} @programs_to_install ],
  'clean'	=> {FILES => '$(EXE_FILES)' },
  'dist'        => {
    'COMPRESS'  => 'gzip',
    'SUFFIX'    => 'gz'
  },
);
