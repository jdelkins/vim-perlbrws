package VimBufList;

=head1 Name

VimBufList - list VIM buffers in a buffer for quick buffer navigation

=head1 DESCRIPTION

Motivated by <C-X><C-B> in emacs, this function will list all active
buffers and allow easy clean up or inter-buffer navigation.

NOTE: this is only useful from within the VIM editor. See
:help perl for more information.

=head1 KEY BINDINGS

=item Initiate:

,b

=item Mark for deletion:

d

=item Delete marked buffers:

x

=item Goto buffer listing:

<CR>

=head1 REQUIRES

Vim_Buffer (see L<Vim_Buffer>)

=head1 SEE ALSO

=item o L<VimFileBrowser>

=item o L<vim>

=item o :help perl

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

use Vim_Buffer;
use Carp;
use vars qw{ $vbname @bufs $did_syntax_inits $i_action $i_number $i_loaded $i_visible $i_count $i_name $a_none $a_del };

BEGIN {
	$did_syntax_inits = 0;
	($i_action, $i_number, $i_loaded, $i_visible, $i_count, $i_name) = (0, 1, 2, 3, 4, 5);
	($a_none, $a_del) = (' ', 'D');
	$vbname = "$ENV{TMP}/_buflist$$";
	VIM::DoCommand('nnoremap ,b :perl VimBufList::enter()<CR>');
	VIM::DoCommand('augroup VimBufList');
	VIM::DoCommand('autocmd!');
	VIM::DoCommand('autocmd BufNewFile _buflist* perl VimBufList::list()');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap <CR> :perl VimBufList::goto()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap s :perl VimBufList::gotos()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap r :perl VimBufList::list()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap d :perl VimBufList::mark_del()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap D :perl VimBufList::mark_del_all()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap x :perl VimBufList::exec()<CR>');
	VIM::DoCommand('autocmd BufEnter _buflist* nnoremap q :bd!<CR>');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap <CR>');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap s');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap r');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap d');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap D');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap x');
	VIM::DoCommand('autocmd BufLeave _buflist* nunmap q');
	VIM::DoCommand('augroup END');
}

##########################################################
# subs callable from VIM (public subs)
##########################################################

# entry point; map this to a keystroke
sub enter {
	my $mod = VIM::Eval('&modified');
	if ($mod) {
		VIM::DoCommand("new $vbname");
	} else {
		VIM::DoCommand("edit $vbname");
	}
}

# this to be called from autocmd BufNewFile
sub list {
	&do_syntax();
	my @vbufs = VIM::Buffers();
	@bufs = ();
	foreach (@vbufs) {
		my ($loaded, $visible, $count) = (0, 0, $_->Count());
		if (VIM::Eval('exists("*bufloaded")') and VIM::Eval('exists("*bufwinnr")')) {
			$loaded  = VIM::Eval("bufloaded(".$_->Number().")");
			$visible = VIM::Eval("bufwinnr(".$_->Number().")") > 0;
			$count = 0 unless $loaded;
		}
		push @bufs, [ $a_none, $_->Number(), $loaded, $visible, $count, $_->Name() ];
	}
	&relist();
}

# mark current line for deletion
sub mark_del {
	my $line = VIM::Eval('line(".")');
	return if $line < 2;
	$line -= 2;
	confess "OOB" unless $bufs[$line];
	if ($bufs[$line]->[$i_action] eq $a_del) {
		$bufs[$line]->[$i_action] = $a_none;
	} else {
		$bufs[$line]->[$i_action] = $a_del;
	}
	&relist();
}

# mark all buffers for deletion
sub mark_del_all {
	map { $_->[$i_action] = $a_del } @bufs;
	&relist();
}

# execute the marked deletions
sub exec {
	my @dellist = grep { $_->[$i_action] eq $a_del } @bufs;
	@dellist = map { $_->[$i_number] } @dellist;
	VIM::DoCommand("bd @dellist");
	&enter();
}

# split the window and go to the highlighted buffer
sub gotos {
	my $line = VIM::Eval('line(".")');
	return if $line < 2;
	$line -= 2;
	confess "OOB" unless $bufs[$line];
	VIM::DoCommand("sb ". $bufs[$line]->[$i_number]);
}

# go to the highlighted buffer
sub goto {
	my $line = VIM::Eval('line(".")');
	return if $line < 2;
	$line -= 2;
	confess "OOB" unless $bufs[$line];
	VIM::DoCommand("b ". $bufs[$line]->[$i_number]);
}


##########################################################
# private subs
##########################################################

# call this to set up syntax items (from autocmd BufEnter, or from &list())
sub do_syntax {
	VIM::DoCommand('syntax clear');
	VIM::DoCommand('syntax case match');
	VIM::DoCommand('syntax match vbTitle "^A.*"');
	VIM::DoCommand("syntax match vbDelete contains=vbBufNumber \"^$a_del.*\"");
	VIM::DoCommand("syntax match vbNone   contains=vbBufNumber \"^$a_none.*\"");
	VIM::DoCommand('syntax match vbBufNumber " \<\d\+\> "ms=s+1,me=e-1');
	if (!$did_syntax_inits) {
		$did_syntax_inits = 1;
		VIM::DoCommand("highlight link vbTitle     Title");
		VIM::DoCommand("highlight link vbDelete    Visual");
		VIM::DoCommand("highlight link vbNone      Normal");
		VIM::DoCommand("highlight link vbBufNumber Identifier");
	}
}

# call this after any change that will affect the visual appearance (e.g., marking)
sub relist {
	VIM::DoCommand("set noro");
	tie my @b, 'Vim_Buffer', '%';
	@b = ();
	$b[0] =        sprintf('%1s %4s  %5s  %6s %s', "A", "Num", "Flags", "Count", "Name");
	push @b, map {
		sprintf('%1s %4d  %1s%1s     %6s %s',
			$_->[$i_action],
			$_->[$i_number],
			$_->[$i_loaded] ? 'L' : '-',
			$_->[$i_visible] ? 'V' : '-',
			$_->[$i_loaded] ? $_->[$i_count] : '-',
			$_->[$i_name])
	} @bufs;
	untie @b;
	VIM::DoCommand("set nomodified");
	VIM::DoCommand("set ro");
}

1;
