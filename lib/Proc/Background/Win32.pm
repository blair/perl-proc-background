package Proc::Background::Win32;

require 5.004_04;

BEGIN {
  eval "use Win32::Process";
  $@ and die "Proc::Background::Win32 needs Win32::Process from libwin32-?.??.zip to run.\n";
}

use strict;
use vars qw(@ISA $VERSION);
use Exporter;
use Carp qw(confess croak carp cluck);

$VERSION = do {my @r=(q$Revision: 0.01 $=~/\d+/g);sprintf "%d."."%02d"x$#r,@r};
@ISA     = qw(Exporter);

sub new {
  my $class = shift;

  @_ or croak "$0: new $class called with insufficient number of arguments";
  my $program = shift;
  if (!-x $program) {
    if (-x "$program.exe") {
      $program .= ".exe";
    }
    else {
      cluck "$program not found or is not executable.\n";
      return;
    }
  }

  my $self = bless {}, $class;

  # Perl 5.004_04 cannot do Win32::Process::Create on a nonexistant
  # hash key.
  $self->{_os_obj} = 0;

  # Create the process.
  if (Win32::Process::Create($self->{_os_obj},
			     $program,
			     "$program @_",
			     0,
			     NORMAL_PRIORITY_CLASS,
			     '.')) {
    return $self;
  }
  else {
    return;
  }
}

# Reap the child.
sub _waitpid {
  my $self = shift;
  my $timeout = shift;

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

sub alive {
  my $self = shift;

  exists($self->{_os_obj}) or
    return 0;
  $self->{_os_obj}->Wait(0);
}

sub die {
  my $self = shift;

  exists($self->{_os_obj}) or
    return 1;

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

  !$self->alive;
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
