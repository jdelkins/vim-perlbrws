package Vim_Buffer;

=head1 NAME

Vim_Buffer - tie a perl array to a VIM buffer

=head1 SYNOPSYS

=over 4

:perl use Vim_Buffer;
:perl tie(@buf, 'Vim_Buffer', '/etc/passwd'); # you must already be editing /etc/passwd
:perl $buf[$#buf+1] = "nobody:x:500:500:nobdy:/:/bin/zsh"; # add a line
:perl $#buf += 1; # add a blank line to the end
:perl foreach (@buf) { my @f = split ':'; $f[1] = 'x'; @_ = join(':', @f); }; # change each p/w to x
:perl untie @buf

=back

=head1 DESCRIPTION

One complaint of mine about the VIM/perl interface is that accessing
VIM buffers from perl is a bit cumbersome but plenty powerful. I
therefore have written this package to make it easier to process a VIM
buffer through perl. It is a perltie package for use with the VIM
editor. Of course, it requires that VIM be compiled with perl enabled.

To use it, tie an array to the Vim_Buffer package (see L<perltie>).
Thereafter, you can access the buffer using standard perl array
manipulation (including push, pop, join, etc.) You can use $# to set
the number of lines in the buffer.

NOTE: this is by no means a stand alone package; it can be used only
from within the VIM editor.

I realize that the above example is more easily done using standard
editing. The best utility of this package is derived when processing
two or more files in complex ways for which you normally would use
perl anyway. With this package, each change is easily undoable, you
can do complex processing in a step-by-step manner, and you can see
each change in the editor as it happens.

Of course, with the proper perl packages, you can do really cool
stuff, like database lookups or what have you.

=head1 SEE ALSO

L<perl.vim> - my VIM command file that provides an easy-to-use
facility for running perl code from within VIM. This module can
enhance the utility of perl.vim considerably.

L<Tie::Array> - The base class for this package.

<URL:http://www.vim.org/> - The VIM homepage.

=head1 COPYING

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
USA.

See the full GPL at <URL:http://www.gnu.org/copyleft/gpl.html>

=cut

use Tie::Array;
use strict;
use vars qw{ @bufs };
use Carp qw{ confess cluck };

BEGIN{
	@Vim_Buffer::ISA = ('Tie::Array');
}

# start, end must be > 0 if specified.

# Constructor - one argument, the name or number of a VIM buffer
sub TIEARRAY {
	my $class   = shift;
	my $bufid   = shift;
	my $start   = shift;
	my $end     = shift;
	my $buffer  = VIM::Buffers($bufid);
	cluck "USAGE: tie(\@ary, '$class', \$buf_name_or_number, \$start, \$end). WARNING: extra parameters ignored" if @_;
	confess "start > end ($start > $end)" if $start > $end;
	#confess "$bufid does not (uniquely) specify a buffer. Bailing" unless $buffer;
	return undef unless $buffer;
	$start = 0 if $start < 0;
	$end   = 0 if $end > $buffer->Count() || $end < 0;
	my ($rc, $vimvers) = VIM::Eval("version");
	confess "VIM version $vimvers too old or unable to determine version. tie is disallowed" if !$rc || $vimvers < 503;
	($rc, my $has_bufloaded) = VIM::Eval('exists("*bufloaded")');
	if (!$rc) {
		cluck "Unable to determine if bufloaded() is available";
		$has_bufloaded = undef;
	}
	# if we're running version 5.4 or later, there are some extra things we can do...
	if ($has_bufloaded) {
		# ensure that the tied buffer is loaded, by :sb if necessary
		# If the buffer isn't loaded, then changes to the array will silently fail...
		($rc, my $loaded) = VIM::Eval("bufloaded(".$buffer->Number().")");
		if (!$rc) {
			cluck "Unable to determine if buffer is loaded" 
		} elsif (!$loaded) {
			return undef;
		}
	}
	return bless {
		BUFID  => $bufid,
		BUFFER => $buffer,
		LSTART => $start,
		LEND   => $end,
	}, $class;
}

# logical out-of-bounds
sub loob {
	my ($self, $idx) = @_;
	confess "Buffer no longer exists" unless $self->{BUFFER};
	confess "Attempt to access negative index $idx" if $idx < 0;
	$idx += ($self->{LSTART} - 1) if $self->{LSTART};
	my $max = $self->{LEND} ? $self->{LEND} - 1   : $self->{BUFFER}->Count() - 1;
	return 1 if $idx > $max;
	return 0;
}

sub FETCH {
	my ($self, $idx) = @_;
	confess "Buffer no longer exists" unless $self->{BUFFER};
	if ($self->loob($idx)) {
		return undef;
	}
	$idx += ($self->{LSTART} - 1) if $self->{LSTART};
	return $self->{BUFFER}->Get($idx + 1);
}

# store value in the logical buffer, expanding it if the index is out of bounds
sub STORE {
	my ($self, $idx, $val) = @_;
	confess "Buffer no longer exists" unless $self->{BUFFER};

	my $oob = $self->loob($idx);                       # test for logical oob
	if ($oob) {
		$self->STORESIZE($idx + 1);                # expand logical array
	}
	$idx += ($self->{LSTART} - 1) if $self->{LSTART};  # adjust index
	$self->{BUFFER}->Set($idx + 1, $val);              # set the relevant line
}

# fetch the size of the logical buffer
sub FETCHSIZE {
	my $self = shift;
	confess "Buffer no longer exists" unless $self->{BUFFER};
	my $max = $self->{LEND} ? $self->{LEND} : $self->{BUFFER}->Count();
	my $min = $self->{LSTART} ? $self->{LSTART} - 1 : 0;
	return $max - $min;
}

# resize the logical buffer (and the physical one if necessary)
sub STORESIZE {
	my ($self, $size) = @_;           # $size is the desired new size
	confess "Buffer no longer exists" unless $self->{BUFFER};
	confess "Attempt to resize array to negative value $size" if $size < 0;
	my $cursize = $self->FETCHSIZE(); # current logical size
	my $end     = ($self->{LSTART} ? $self->{LSTART} - 1 : 0) + $cursize;

	if ($size > $cursize) {                            # expand
		my $diff = $size - $cursize;
		my @blanks = ("") x $diff;
		$self->{BUFFER}->Append($end, @blanks);
		$self->{LEND} += $diff if $self->{LEND};
	} elsif ($cursize > $size) {                       # shrink
		my $diff = $cursize - $size;
		$self->{BUFFER}->Delete($end - $diff + 1, $end);
		$self->{LEND} -= $diff if $self->{LEND};
	}
}

sub DESTROY {
	my $self = shift;
	$self->{BUFFER} = undef;
	$self->{BUFID}  = undef;
	$self->{LSTART} = undef;
	$self->{LEND}   = undef;
}

1;




