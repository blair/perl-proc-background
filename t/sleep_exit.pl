$| = 1;

my $sleep       = shift || 1;
my $exit_status = shift || 0;

if ($ENV{VERBOSE}) {
  print STDERR "SLEEP_EXIT.PL: sleep $sleep and exit $exit_status.\n";
}

sleep $sleep;

if ($ENV{VERBOSE}) {
  print STDERR "SLEEP_EXIT.PL now exiting\n";
}

exit $exit_status;
