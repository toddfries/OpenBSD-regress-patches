#	$OpenBSD: Remote.pm,v 1.2 2013/06/04 04:17:42 bluhm Exp $

# Copyright (c) 2010-2013 Alexander Bluhm <bluhm@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;

package Remote;
use parent 'Proc';
use Carp;
use Cwd;
use File::Basename;

sub new {
	my $class = shift;
	my %args = @_;
	$args{logfile} ||= "remote.log";
	$args{up} ||= "Started";
	$args{func} = sub { Carp::confess "$class func may not be called" };
	$args{remotessh}
	    or croak "$class remote ssh host not given";
	my $self = Proc::new($class, %args);
	$self->{af}
	    or croak "$class address family not given";
	$self->{bindaddr}
	    or croak "$class bind addr not given";
	$self->{connectaddr}
	    or croak "$class connect addr not given";
	defined $self->{connectport}
	    or croak "$class connect port not given";
	return $self;
}

sub up {
	my $self = Proc::up(shift, @_);
	my $timeout = shift || 10;
	if ($self->{connect}) {
		$self->loggrep(qr/^Connected$/, $timeout)
		    or croak ref($self), " no Connected in $self->{logfile} ".
			"after $timeout seconds";
		return $self;
	}
	my $lsock = $self->loggrep(qr/^listen sock: /, $timeout)
	    or croak ref($self), " no listen sock in $self->{logfile} ".
		"after $timeout seconds";
	my($addr, $port) = $lsock =~ /: (\S+) (\S+)$/
	    or croak ref($self), " no listen addr and port in $self->{logfile}";
	$self->{listenaddr} = $addr;
	$self->{listenport} = $port;
	return $self;
}

sub child {
	my $self = shift;

	print STDERR $self->{up}, "\n";
	my @opts = split(' ', $ENV{SSH_OPTIONS}) if $ENV{SSH_OPTIONS};
	my @sudo = $ENV{SUDO} ? ($ENV{SUDO}, "SUDO=$ENV{SUDO}") : ();
	my $dir = dirname($0);
	$dir = getcwd() if ! $dir || $dir eq '.';
	my @cmd = ('ssh', '-n', @opts, $self->{remotessh}, @sudo, 'perl',
	    '-I', $dir, "$dir/".basename($0), $self->{af},
	    $self->{bindaddr}, $self->{connectaddr}, $self->{connectport},
	    ($self->{testfile} ? "$dir/".basename($self->{testfile}) :
	    ()));
	print STDERR "execute: @cmd\n";
	$< = $>;
	exec @cmd;
	die "Exec @cmd failed: $!";
}

1;
