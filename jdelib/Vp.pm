package Vp;

=head1 NAME

Vp - VIM/Perl add-ons

=head1 SYNOPSYS

=over 4

:perl $a = Vp::abyname("/etc/passwd"); # tie passwd to @$a
:perl map { s/^nobody/noone/ } @$a;    # rename nobody
:perl $b = Vp::abynr(2);               # tie buf 2 to @$b
:perl &Vp::do_vimperl                  # process perl in ~/.vimperl buffer

=back

=head1 DESCRIPTION

The main feature here is a perl sub which will evaluate a buffer named
~/.vimperl. This makes it easy to put text processing code into
~/.vimperl and run it (from any buffer) using :perl &Vp::do_vimperl --
you don't even have to save the ~/.vimperl file first. Just hack in
some perl code (see :help perl-using).

Additionally, there are a couple of companion subroutines for use
with the companion Vim_Buffer package (see L<Vim_Buffer>).

=head2 abyname($)

=item Params:

(partial but unique) name of a buffer

=item Returns:

tie'd array reference, representing the buffer

=item Errors:

if the buffer not found or not unique, will confess

=head2 abynr($)

=item Params:

numerical buffer number (as shown in :ls)

=item Returns:

tie'd array reference, representing the buffer

=item Errors:

if the buffer number was not found, will confess

=head2 do_vimperl()

=item Params:

none

=item Returns:

nothing

=item Errors:

reported via VIM::Msg()

=item Notes:

evaluates the buffer named ".vimperl". If this buffer cannot be found
and cannot be loaded, then the operation fails. The buffer does not
need to be saved before running do_vimperl().

=head1 EXAMPLE

=item Objective:

Comment out lines that start with "cd"

=item Preconditions:

The file you're processing is called "/usr/local/bin/foo.sh"

=item Code:

(put in ~/.vimperl, then issue :Vp)

=item Notes:

See the L<Vim_Buffer> package to learn how the tie interface works.

=over 4

  my $lines = abyname("foo.sh");
  for my $i (@$lines) {
     $i =~ s/^cp/# cp/;
  }

=back

=head1 COPYING

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

(see the full GPL license at http://www.gnu.org/copyleft/gpl.html)

=cut

use Carp;
use Vim_Buffer;
use vars qw{$rstart $rend @r @a @b};

sub nrtoa {
	my $nr = shift;
	confess("buffer #$n not found or not unique") unless $nr;
	my ($rc, $hasbl) = VIM::Eval('exists("*bufloaded")');
	if (!$rc || !$hasbl) {
		warn ("Can't determine if buf #$nr is loaded. Operations may have no effect.");
	} else {
		($rc, my $loaded) = VIM::Eval("bufloaded($nr)");
		if (!$rc) {
			warn ("Can't determine if buf #$nr is loaded. Operations may have no effect.");
		} elsif (!$loaded) {
			VIM::DoCommand("sb$nr");
		}
	}
	warn("Attempting to tie buf $nr");
	tie (my @c, 'Vim_Buffer', $nr, @_);
	return \@c;
}

sub abyname {
	my $n = shift or confess("string parameter required");
	my ($rc, $nr) = VIM::Eval("bufnr('$n')");
	confess("VIM call to bufnr() failed") unless $rc;
	return nrtoa($nr, @_);
}

sub abynr {
	my $n = shift;
	if (!($n > 0)) {
		confess("numeric parameter required");
	}
	return Vp::nrtoa($n, @_);
}

sub perlwarn {
	(my $msg = $_[0]) =~ s/	/    /g; # it's a tab character that we're replacing
	VIM::Msg($msg, "WarningMsg");
}

sub perlerr {
	(my $msg = $_[0]) =~ s/	/    /g; # it's a tab character that we're replacing
	VIM::Msg($msg, "ErrorMsg");
}

sub do_vimperl {
	tie(@a, 'Vim_Buffer', '%');
	tie(@b, 'Vim_Buffer', '#');
	($rstart, $rend) = @_;
	if ($rstart && $rend) {
		tie(@r, 'Vim_Buffer', '%', $rstart, $rend);
		$rstart -= 1;
		$rend   -= 1;
	} else {
		@r = ();
	}

	local($SIG{__WARN__}, $SIG{__DIE__}) = (\&perlwarn, \&perlerr);
	my $buf = VIM::Buffers(".vimperl");
	confess("Unable to find .vimperl buffer") unless $buf;
	my $cmd = "";
	foreach my $i (1..$buf->Count())  {
		$cmd .= $buf->Get($i) . "\n";
	}
	eval $cmd;
	if ($@) {
		VIM::Msg("NOTE: You may need to hit ^L to see changes.", "WarningMsg");
	} else {
		VIM::DoCommand("normal \014");
	}
}

sub do_vp_cmd {
	tie(@a, 'Vim_Buffer', '%');
	tie(@b, 'Vim_Buffer', '#');
	($cmd, $rstart, $rend) = @_;
	confess 'USAGE: do_vp_cmd($cmd, $range_start, $range_end)' if !$cmd;
	if ($rstart && $rend) {
		tie(@r, 'Vim_Buffer', '%', $rstart, $rend);
		$rstart -= 1;
		$rend   -= 1;
	} else {
		@r = ();
	}
	local($SIG{__WARN__}, $SIG{__DIE__}) = (\&perlwarn, \&perlerr);
	eval $cmd;
	if ($@) {
		VIM::Msg("NOTE: You may need to hit ^L to see changes.", "WarningMsg");
	} else {
		VIM::DoCommand("normal \014");
	}
}

sub tie_range {
	my ($arrayname, $start, $end) = @_ or confess("USAGE: map_range(\$array_name). Argument required");
	local($SIG{__WARN__}, $SIG{__DIE__}) = (\&perlwarn, \&perlerr);
	eval "tie \@$arrayname, 'Vim_Buffer', '%', $start, $end";
}

1;


