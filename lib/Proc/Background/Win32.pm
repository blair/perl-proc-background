# Proc::Background::Win32 Windows interface to background process management.
#
# Copyright (C) 1998-2000, Blair Zajac.

package Proc::Background::Win32;

require 5.004_04;

use strict;
use vars qw(@ISA $VERSION);
use Exporter;
use Carp qw(cluck);

BEGIN {
  eval "use Win32::Process";
  $@ and die "Proc::Background::Win32 needs Win32::Process from libwin32-?.??.zip to run.\n";
}

@ISA     = qw(Exporter);
$VERSION = substr q$Revision: 1.00 $, 10;

sub new {
  my $class = shift;

  unless (@_ > 0) {
    cluck "$class::new called with insufficient number of arguments";
    return;
  }

  my ($program, @args) = @_;

  my $self = bless {}, $class;

  # If an argument contains any characters that require protecting
  # since the command is converted into a single string, quote it.
  for (my $i=0; $i<@args; ++$i) {
    if (index($args[$i], ' ') != -1) {
        $args[$i] = "\"$args[$i]\"";
    }
  }

  # Perl 5.004_04 cannot do Win32::Process::Create on a nonexistant
  # hash key.
  my $os_obj = 0;

  # Create the process.
  if (Win32::Process::Create($os_obj,
			     $program,
			     "$program @args",
			     0,
			     NORMAL_PRIORITY_CLASS,
			     '.')) {
    $self->{_pid}    = $os_obj->GetProcessID;
    $self->{_os_obj} = $os_obj;
    return $self;
  } else {
    return;
  }
}

# Reap the child.
sub _waitpid {
  my ($self, $timeout) = @_;

  # Try to wait on the process.
  my $result = $self->{_os_obj}->Wait($timeout ? INFINITE : 0);
  # Process finished.  Grab the exit value.
  if ($result == 1) {
    my $_exit_status;
    $self->{_os_obj}->GetExitCode($_exit_status);
    return (0, $_exit_status<<8);
  }
  # Process still running.
  elsif ($result == 0) {
    return (2, 0);
  }
  # If we reach here, then something odd happened.
  return (0, 1<<8);
}

sub _die {
  my $self = shift;

  # Try the kill the process several times.  Calling alive() will
  # collect the exit status of the program.
  SIGNAL: {
    my $count = 5;
    while ($count and $self->alive) {
      --$count;
      my $res = $self->{_os_obj}->Kill(1<<8);
      last SIGNAL unless $self->alive;
      sleep 1;
    }
  }
}

1;

__END__

=head1 NAME

Proc::Background::Win32 - Interface to process mangement on Win32 systems

=head1 SYNOPSIS

Do not use this module directly.

=head1 DESCRIPTION

This is a process management class designed specifically for Win32
operating systems.  It is not meant used except through the
I<Proc::Background> class.  See L<Proc::Background> for more information.

=head1 IMPLEMENTATION

This package uses the Win32::Process class to manage the objects.

=head1 AUTHOR

Blair Zajac <blair@gps.caltech.edu>

=head1 COPYRIGHT

Copyright (c) 1998 Blair Zajac. All rights reserved.  This package is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
