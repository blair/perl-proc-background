# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use vars qw($loaded);

BEGIN { $| = 1; print "1..22\n"; }
END   {print "not ok 1\n" unless $loaded; }

my $ok_count = 1;
sub ok {
  shift or print "not ";
  print "ok $ok_count\n";
  ++$ok_count;
}

use Proc::Background qw(timeout_system);

package EmptySubclass;
use Proc::Background;
use vars qw(@ISA);
@ISA = qw(Proc::Background);

package main;

# If we got here, then the package being tested was loaded.
$loaded = 1;
ok(1);								# 1

# Find the sleep_exit.pl code.  This script takes a sleep time and an
# exit value.
my $sleep_exit;
foreach my $dir (qw(. ./t Proc-Background/t)) {
  my $s = "$dir/sleep_exit.pl";
  -r $s or next;
  $sleep_exit = $s;
  last;
}
$sleep_exit or die "Cannot find sleep_exit.pl.\n";

# Test the alive and wait returns.
my $p1 = EmptySubclass->new($^X, $sleep_exit, 2, 26);
ok($p1);							# 2
if ($p1) {
  ok($p1->alive);						# 3
  sleep 3;
  ok(!$p1->alive);						# 4
  ok(($p1->wait >> 8) == 26);					# 5
} else {
  ok(0);							# 3
  ok(0);							# 4
  ok(0);							# 5
}

# Test alive, wait, and die on already dead process.  Also pass some
# bogus command line options to the program to make sure that the
# argument protecting code for Windows does not cause the shell any
# confusion.
my $p2 = EmptySubclass->new($^X,
                            $sleep_exit,
                            2,
                            5,
                            "\t",
                            '"',
                            '\" 10 \\" \\\\"');
ok($p2);							# 6
if ($p2) {
  ok($p2->alive);						# 7
  ok(($p2->wait >> 8) == 5);					# 8
  ok($p2->die);							# 9
  ok(($p2->wait >> 8) == 5);					# 10
} else {
  ok(0);							# 7
  ok(0);							# 8
  ok(0);							# 9
  ok(0);							# 10
}

# Test die on a live process and collect the exit value.  The exit
# value should not be 0.
my $p3 = EmptySubclass->new($^X, $sleep_exit, 10, 0);
ok($p3);							# 11
if ($p3) {
  ok($p3->alive);						# 12
  sleep 1;
  ok($p3->die);							# 13
  ok(!$p3->alive);						# 14
  ok($p3->wait);						# 15
  ok($p3->end_time > $p3->start_time);				# 16
} else {
  ok(0);							# 12
  ok(0);							# 13
  ok(0);							# 14
  ok(0);							# 15
  ok(0);							# 16
}

# Test the timeout_system function.  In the first case, sleep_exit.pl
# should exit with 26 before the timeout, and in the other case, it
# should be killed and exit with a non-zero status.
ok((timeout_system(2, $^X, $sleep_exit, 0, 26) >> 8) == 26);	# 17
ok(timeout_system(1, $^X, $sleep_exit, 4, 0));			# 18

# Test the code to find a program if the path to it is not absolute.
my $p4 = EmptySubclass->new('perl', $sleep_exit, 0, 0);
ok($p4);							# 19
if ($p4) {
  ok($p4->pid);							# 21
  sleep 2;
  ok(!$p4->alive);						# 21
  ok(($p4->wait >> 8) == 0);					# 22
} else {
  ok(0);							# 20
  ok(0);							# 21
  ok(0);							# 22
}
