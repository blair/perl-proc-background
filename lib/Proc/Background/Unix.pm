# Proc::Background::Unix: Unix interface to background process management.
#
# Copyright (C) 1998-2000, Blair Zajac.

package Proc::Background::Unix;

require 5.004_04;

use strict;
use vars qw(@ISA $VERSION);
use Exporter;
use Carp qw(cluck croak);
use POSIX qw(:errno_h :sys_wait_h);

@ISA     = qw(Exporter);
$VERSION = substr q$Revision: 0.03 $, 10;

# Start the background process.  If it is started sucessfully, then record
# the process id in $self->{_os_obj}.
sub new {
  my $class = shift;

  unless (@_ > 0) {
    cluck "$class::new called with insufficient number of arguments";
    return;
  }

  my $self = bless {}, $class;
  
  # Fork a child process.
  my $pid;
  {
    if ($pid = fork()) {
      # parent
      $self->{_os_obj} = $pid;
      $self->{_pid}    = $pid;
      last;
    } elsif (defined $pid) {
      # child
      exec @_ or croak "$0: exec failed: $!\n";
    } elsif ($! == EAGAIN) {
      sleep 5;
      redo;
    } else {
      return;
    }
  }

  $self;
}

# Wait for the child.
sub _waitpid {
  my $self    = shift;
  my $timeout = shift;

  {
    # Try to wait on the process.
    my $result = waitpid($self->{_os_obj}, $timeout ? 0 : WNOHANG);
    # Process finished.  Grab the exit value.
    if ($result == $self->{_os_obj}) {
      return (0, $?);
    }
    # Process already reaped.  We don't know the exist status.
    elsif ($result == -1 and $! == ECHILD) {
      return (1, 0);
    }
    # Process still running.
    elsif ($result == 0) {
      return (2, 0);
    }
    # If we reach here, then waitpid caught a signal, so let's retry it.
    redo;
  }
  return 0;
}

sub _die {
  my $self = shift;

  # Try to kill the process with different signals.  Calling alive() will
  # collect the exit status of the program.
  SIGNAL: {
    foreach my $signal (qw(HUP QUIT INT KILL)) {
      my $count = 5;
      while ($count and $self->alive) {
        --$count;
        kill($signal, $self->{_os_obj});
        last SIGNAL unless $self->alive;
        sleep 1;
      }
    }
  }
}

1;

__END__

=head1 NAME

Proc::Background::Unix - Unix interface to process mangement

=head1 SYNOPSIS

Do not use this module directly.

=head1 DESCRIPTION

This is a process management class designed specifically for Unix
operating systems.  It is not meant used except through the
I<Proc::Background> class.  See L<Proc::Background> for more information.

=head1 AUTHOR

Blair Zajac <blair@gps.caltech.edu>

=head1 COPYRIGHT

Copyright (c) 1998 Blair Zajac. All rights reserved.  This package is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
