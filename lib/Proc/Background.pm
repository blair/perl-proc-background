package Proc::Background;

require 5.004_04;

use strict;
use vars qw(@ISA $VERSION @EXPORT_OK);
use Exporter;
use Carp qw(confess croak carp cluck);

$VERSION = do {my @r=(q$Revision: 0.01 $=~/\d+/g);sprintf "%d."."%02d"x$#r,@r};
@ISA       = qw(Exporter);
@EXPORT_OK = qw(timeout_system);

# Make this class a subclass of Proc::Win32 or Proc::Unix.  Any
# unresolved method calls will go to either of these classes.
OS: {
  if ($^O eq 'MSWin32') {
    require Proc::Background::Win32;
    unshift(@ISA, 'Proc::Background::Win32');
    last OS;
  }
  require Proc::Background::Unix;
  unshift(@ISA, 'Proc::Background::Unix');
  last OS;
}

# We want the created object to live in Proc::Background instead of the
# OS specific class so that generic method calls can be used.
sub new {
  my $class = shift;

  @_ > 0 or croak "$0: new $class called with insufficient number of arguments";

  my $self = $class->SUPER::new(@_) or return;

  # Save the start time of the class.
  $self->{_start_time} = time;

  bless $self, $class;
}

# Reap the child.  If the first argument is 0 the wait should return
# immediately, 1 if it should wait forever.  If this number is
# negative, then wait.  If the wait was sucessful, then delete
# $self->{_os_obj} and set $self->{_exit_value} to the OS specific
# class return of _reap.  Return 1 if we sucessfully waited, 0
# otherwise.
sub _reap {
  my $self = shift;
  my $timeout = shift || 0;

  exists($self->{_os_obj}) or return 0;

  # Try to wait on the process.  Use the OS dependent wait call using
  # _waitpid, which returns one of three values.
  #   (0, exit_value)	: sucessfully waited on.
  #   (1, undef)	: process already reaped and exist value lost.
  #   (2, undef)	: process still running.
  my ($result, $exit_value) = $self->_waitpid($timeout);
  if ($result == 0 or $result == 1) {
    $self->{_exit_value} = defined($exit_value) ? $exit_value : 0;
    delete $self->{_os_obj};
    # Save the end time of the class.
    $self->{_end_time} = time;
    return 1;
  }
  return 0;
}

sub alive {
  my $self = shift;

  # If $self->{_os_obj} is not set, then the process is definitely
  # not running.
  exists($self->{_os_obj}) or
    return 0;

  # If $self->{_exit_value} is set, then the process has already finished.
  exists($self->{_exit_value}) and
    return 0;

  # Try to reap the child.  If it doesn't reap, then it's alive.
  !$self->_reap(0);
}

sub wait {
  my $self = shift;

  # If neither _os_obj or _exit_value are set, then something is wrong.
  if (!exists($self->{_exit_value}) and !exists($self->{_os_obj})) {
    return;
  }

  # If $self->{_exit_value} exists, then we already waited.
  exists($self->{_exit_value}) and
    return $self->{_exit_value};

  # Otherwise, wait forever for the process to finish.
  $self->_reap(1);
  return $self->{_exit_value};
}

sub start_time {
  my $self = shift;

  $self->{_start_time};
}

sub end_time {
  my $self = shift;

  $self->{_end_time};
}

sub timeout_system {
  @_ > 1 or
    croak "$0: timeout_system passed wrong number of arguments.\n";
  my $timeout = shift;
  my $proc = Proc::Background->new(@_) or return;
  my $end_time = $proc->start_time + $timeout;
  while ($proc->alive and time < $end_time) {
    sleep(1);
  }
  if ($proc->alive) {
    $proc->die;
  }
  $proc->wait;
}

1;

__END__

=pod

=head1 NAME

Proc::Background - Generic interface to Unix and Win32 background process management

=head1 SYNOPSIS

    use Proc::Background;
    timeout_system('seconds', 'path_to_program', 'arg1');
    my $proc = Proc::Background->new('path_to_program', 'arg1', 'arg2');
    $proc->alive;
    $proc->die;
    $proc->wait;
    $time = $proc->start_time;
    $time = $proc->end_time;

=head1 DESCRIPTION

This is a generic interface to place programs in background processing
on both Unix and Win32 platforms.  This class lets you start, kill, wait
on, retrieve exit values, and see if background processes are alive.

=head1 METHODS

=over 4

=item B<new> I<path> [I<arg>, [I<arg>, ...]]

This creates a new background process.  The complete pathname to the
executable must be passed as the first argument to this method.  This
is required for compatibility for running programs on Win32 platform.
If anything fails, then new returns an empty list in a list context, an
undefined value in a scalar context, or nothing in a void context.

=item B<alive>

Return 1 if the process is still active, 0 otherwise.

=item B<die>

Reliably try to kill the process.  Returns 1 if the process no longer
exists, 0 otherwise.  On Unix, use signals in the following order:
HUP, QUIT, INT, KILL.

=item B<wait>

Wait for the process to exit.  Return the exit status of the program
as returned by I<wait>() on the system.  To get the actual exit value,
divide by 256, regardless of the operating system being used.  If the
process never existed, then return an empty list in a list context, an
undefined value in a scalar context, or nothing in a void context.  This
function may be called multiple times even after the process has exited
and it will return the same exit status.

=item B<start_time>

Return the value that I<time>() returned when the process was started.

=item B<end_time>

Return the value that I<time>() returned when the exit status was obtained
from the process.

=back

=head1 FUNCTIONS

=over 4

=item B<timeout_system> I<timeout> I<path> [I<arg>, [I<arg>...]]

Run a command for I<timeout> seconds and if the process did not exit,
then kill it.  The location of the program must be used passed in
I<path>.  While the timeout is implemented using I<sleep>(), this function
makes sure that the full I<timeout> is reached before I<kill>ing the process.
The return is the exit status returned from the I<wait>() call.  To get
the actual exit value, divide by 256.  If something failed in the creation
of the process, it returns an empty list in a list context, an undefined
value in a scalar context, or nothing in a void context.

=back

=head1 IMPLEMENTATION

I<Proc::Background> comes with two packages, I<Proc::Background::Unix>
and I<Proc::Background::Win32>.  Currently, on the Unix platform
I<Proc::Background> it uses the I<Proc::Background::Unix> class and on
the Win32 platform I<Proc::Win32>, which makes use of I<Win32::Process>,
is used.

The I<Proc::Background> is package that just assigns to @ISA either
I<Proc::Unix> or I<Proc::Win32>, which does the OS dependent work.  The
OS independent work is done in I<Proc::Background>.

Use two variables to keep track of the process.  $self->{_os_obj} contains
the operating system object to reference the process.  On a Unix systems
this is the process id (pid).  On Win32, it is an object returned from
the I<Win32::Process> class.  When $self->{_os_obj} exists, then the program
is running.  When the program dies, this is recorded by deleting
$self->{_os_obj} and saving $@ into $self->{_exit_value}.

Anytime I<alive>() is called, a I<waitpid>() is called on the process and
the return status, if any, is gathered and saved for a call to
I<wait>().  This module does not install a signal handler for SIGCHLD.
If for some reason, the user has installed a signal handler for SIGCHLD,
then, then when this module calls I<waitpid>(), the failure will be noticed
and taken as the exited child, but it won't be able to gather the exit
status.  In this case, the exit status will be set to 0.

=head1 SEE ALSO

See also the L<Proc::Background::Unix> and L<Proc::Background::Win32>
manual pages.

=head1 AUTHOR

Blair Zajac <blair@gps.caltech.edu>

=head1 COPYRIGHT

Copyright (c) 1998 Blair Zajac. All rights reserved.  This package is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
