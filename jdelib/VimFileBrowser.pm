package VimFileBrowser;

use FileBrowser;
use Vim_Buffer;
use Carp;
use vars qw{ $fb @filetype_source $dirfile $did_syntax_inits };

=head1 Name

VimFileBrowser - a simple file browser within the VIM editor.

=head1 DESCRIPTION

Motivated by dired-mode in emacs, this function will list and
navigate among files in the filesystem. Also supports deleting
of files and executing arbitrary commands on subsets of the
files in a directory.

Tested on HP/UX, Linux, Windows NT, and Windows 95. Some
differences exist in the default behavior and capabilities
of some of these platforms (notable limitiations exist with
the win32 OS's).

NOTE: this is only useful from within the VIM editor. See
:help perl for more information.

=head1 KEY BINDINGS

=item Initiate:

,d

=item Toggle a file's mark:

m

=item Delete marked files:

d

=item Goto current file or directory:

<CR>

=item Change directory if listing:

c

=item Change VIM's working directory to the file browser's current directory:

C

=item Change sort method:

s1, s2, s3, s4

=item Toggle whether dot-files are listed

.

=head1 REQUIRES

Vim_Buffer.pm (see L<Vim_Buffer>), FileBrowser.pm (see L<FileBrowser>)

=head1 SEE ALSO

=item o L<FileBrowser>

=item o L<Vim_Buffer>

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

# TODO:
# * readonly on _dir
# * more/better syntax highlighting
# * on open_path, check whether the path is good first.
# * one and only one fb
#   do something with marked files on win32


BEGIN {
	$dirfile = "$ENV{TMP}/_dir$$";
	$fb = new FileBrowser;
	$did_syntax_inits = 0;
	if ($^O eq 'MSWin32') {
		$fb->sort('d');
	} else {
		$fb->sort('D');
	}
	VIM::DoCommand('nnoremap ,d :perl my $d = VIM::Eval("expand(\"%:p:h\")"); VimFileBrowser::enter($d)<CR>');
	VIM::DoCommand('augroup VimFileBrowser');
	VIM::DoCommand('autocmd!');
	VIM::DoCommand('autocmd BufNewFile _dir* perl VimFileBrowser::list()');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap <CR> :perl VimFileBrowser::do_open_file_or_directory()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap <Tab> 56\|');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap q :bd!<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap . :perl VimFileBrowser::dots_toggle()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap m :perl VimFileBrowser::mark_toggle()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap u :perl VimFileBrowser::mark_toggle()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap M :perl VimFileBrowser::mark_all()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap U :perl VimFileBrowser::unmark_all()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap r :perl VimFileBrowser::list()<CR>');
	#VIM::DoCommand('autocmd BufEnter _dir* nnoremap c :perl VimFileBrowser::do_chdir()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap c :ChdirTo ');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap C :perl VimFileBrowser::do_vim_cd_to_fb_cwd()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap x :perl VimFileBrowser::do_exec()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap sD :perl VimFileBrowser::set_sort("D")<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap sd :perl VimFileBrowser::set_sort("d")<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap sL :perl VimFileBrowser::set_sort("L")<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap sl :perl VimFileBrowser::set_sort("l")<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap st :perl VimFileBrowser::set_sort("t")<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* nnoremap d :perl VimFileBrowser::do_delete()<CR>');
	VIM::DoCommand('autocmd BufEnter _dir* command -nargs=1 -complete=dir ChdirTo :perl VimFileBrowser::do_chdir_to(<q-args>)<CR>');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap <CR>');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap <Tab>');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap q');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap .');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap m');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap u');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap M');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap U');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap r');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap c');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap C');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap x');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap sD');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap sd');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap sL');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap sl');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap st');
	VIM::DoCommand('autocmd BufLeave _dir* nunmap d');
	VIM::DoCommand('autocmd BufLeave _dir* delcommand ChdirTo');
	VIM::DoCommand('augroup END');
	# initialize constants
	@filetype_source = qw{ c h cpp cp pl pm java html sql sh ksh vim tex mp };
}

##########################################################
# subs callable from VIM (public subs)
##########################################################

# to be called from the initial entry point (a VIM map)
# &list() should be called from the BufNewFile autocmd
sub enter {
	my $cwd = shift;
	my $mod = VIM::Eval('&modified');
	if (!$fb->cd($cwd)) {
		VIM::Msg($fb->errm(), "ErrorMsg");
		return;
	}
	my $ch = VIM::Eval('&ch');
	VIM::DoCommand('set ch=2') if $ch < 2;
	if ($mod) {
		VIM::DoCommand("new $dirfile");
	} else {
		VIM::DoCommand("edit $dirfile");
	}
	VIM::DoCommand("set ch=$ch") if $ch < 2;
	VIM::DoCommand('normal 1G');
	VIM::DoCommand('normal 4G');
	VIM::DoCommand('normal 56|');
}

# toggle whether to display dot-files
sub dots_toggle {
	$fb->dots(!$fb->dots());
	&list();
}

# set the sorting method (see L<FileBrowser> for choices)
sub set_sort {
	my $sort = shift;
	$fb->sort($sort);
	&refresh();
	my $msg;
	$msg = "Sort: lexical (case insens)"           if ($sort == 'l');
	$msg = "Sort: lexical (case sens)"             if ($sort == 'L');
	$msg = "Sort: directories first (case insens)" if ($sort == 'd');
	$msg = "Sort: directories first (case sens)"   if ($sort == 'D');
	$msg = "Sort: mod time"                        if ($sort == 't');
	VIM::Msg($msg);
}

# toggle the file mark on the current line
sub mark_toggle {
	my $line = VIM::Eval('line(".")');
	return unless $line > 1; # can't mark the PATH line
	my $mod  = VIM::Eval('&modified');
	die "Buffer modified! Cannot process request." if $mod;
	$line -= 2;
	if ($fb->ismarked($line)) {
		$fb->unmark($line);
		VIM::Msg("1 file unmarked");
	} else {
		$fb->mark($line);
		VIM::Msg("1 file marked");
	}
	&refresh();
	VIM::DoCommand('normal '.($line + 2).'G');
}

# mark all (non-directory) files. only adds to the current
# marks, will not unmark anything.
sub mark_all {
	my $maxind = $main::curbuf->Count() - 1;
	my $line = VIM::Eval('line(".")');
	my @markers;
	for (my $i = 0; $i < $maxind; $i++) {
		push @markers, $i unless $fb->isdir($i);
	}
	$fb->mark(@markers);
	VIM::Msg((scalar @markers) . " files marked");
	&refresh();
	VIM::DoCommand('normal '.$line.'G');
}

# unmark all marked files, directory or non-directory
sub unmark_all {
	my $maxind = $main::curbuf->Count() - 1;
	my $line = VIM::Eval('line(".")');
	my @markers;
	for (my $i = 0; $i < $maxind; $i++) {
		push @markers, $i if $fb->ismarked($i);
	}
	$fb->unmark(@markers);
	VIM::Msg((scalar @markers) . " files unmarked");
	&refresh();
	VIM::DoCommand('normal '.$line.'G');
}

# "open" the file on the current line; if it's a directory,
# change the file browser directory there and re-list; if
# it's a file, edit it in the current window (in place of
# the file browser).
sub do_open_file_or_directory {
	my $line = VIM::Eval('line(".")');
	my $mod  = VIM::Eval('&modified');
	die "Buffer modified! Cannot process request." if $mod;
	if ($line == 1) {
		&do_chdir();
	} else {
		my $file = $fb->fileat($line - 2);
		if ($fb->isdir($line - 2)) {
			&list($file);
		} else {
			$file =~ s/ /\\ /g;
			my $ch = VIM::Eval('&ch');
			VIM::DoCommand("se ch=2") if $ch < 2;
			VIM::DoCommand("e! $file");
			VIM::DoCommand("se ch=$ch") if $ch < 2;
		}
	}
}

# change the file browser directory. prompts the user for where
# to go. does not affect VIM's current directory
sub do_chdir {
	my $d = VIM::Eval('expand(input("chdir to: "))');
	return if ($d =~ /^$/);
	if (!$fb->cd($d)) {
		VIM::Msg($fb->errm(), "ErrorMsg");
	} else {
		&list();
	}
}

# change the file browser directory to the given directory.
# does not affect VIM's current directory
sub do_chdir_to($) {
	my $d = shift;
	$d = VIM::Eval('expand(\''.$d.'\')');
	VIM::Msg($d);
	return if ($d =~ /^$/);
	if (!$fb->cd($d)) {
		VIM::Msg($fb->errm(), "ErrorMsg");
	} else {
		&list();
	}
}

# change VIM's current directory to the file browser's
# current directory (uses :cd)
sub do_vim_cd_to_fb_cwd {
	my $pwd = $fb->cd();
	VIM::DoCommand("cd $pwd");
	VIM::Msg("VIM cd'ed to $pwd");
}


# execute a command, substituting the list of marked files
# in the first ``%s''
sub do_exec {
	my $files = &get_marked_files;
	return unless $files;
	my ($rc, $exec) = VIM::Eval('input("Command: ")');
	return unless $rc;
	my $cmd = sprintf($exec, $files);
	my $output = `$cmd`;
	VIM::Msg("\n$output");
	&list();
}

# delete the marked files (confirm first)
sub do_delete {
	my @files = &get_marked_files();
	return unless @files;
	my @fn = map { $fb->fileat($_) } @files;
	my ($rc, $conf) = VIM::Eval('confirm("Delete '.(scalar @fn).' files?", "&Yes\n&No", 1)');
	return unless $rc;
	if ($conf == 1) {
		unlink @fn;
		&list();
	}
}

# call this to re generate the list. pass in a directory,
# and it will go there first
sub list {
	my $cwd = shift;
	if ($cwd) {
		if (!$fb->cd($cwd)) {
			VIM::Msg($fb->errm(), "ErrorMsg");
			return;
		}
	}
	$fb->ls();
	&refresh();
	&do_syntax();
	VIM::DoCommand('echomsg "' . ($main::curbuf->Count() - 1) . ' files"');
	VIM::DoCommand('normal 1G');
	VIM::DoCommand('normal 4G');
	VIM::DoCommand('normal 56|');
}

##########################################################
# private subs
##########################################################

# call this whenever there is a change to the visual display
# (e.g., marking/unmarking files)
sub refresh {
	tie(my @buf, 'Vim_Buffer', '%');
	my $cwd = $fb->cd();
	VIM::DoCommand('set noro');
	@buf = ("PATH: $cwd");
	push @buf, @{$fb->rels()};
	VIM::DoCommand('set ro');
	VIM::DoCommand('set nomodified');
	untie @buf;
}

# initialize the syntax highlighting for this buffer
sub do_syntax {
	VIM::DoCommand('syntax clear');
	VIM::DoCommand('syntax case match');
	VIM::DoCommand('syntax match fbDir        "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>/$"hs=s+13,he=e-1');
	VIM::DoCommand('syntax match fbDir        "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>/$"hs=s+13,he=e-1');
	VIM::DoCommand('syntax match fbExecutable "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>\*$"hs=s+13,he=e-1');
	VIM::DoCommand('syntax match fbExecutable "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>\*$"hs=s+13,he=e-1');
	VIM::DoCommand('syntax match fbSource     "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\.\('.join('\\|', @filetype_source).'\)\>$"hs=s+13');
	VIM::DoCommand('syntax match fbSource     "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\.\('.join('\\|', @filetype_source).'\)\>$"hs=s+13');
	VIM::DoCommand('syntax match fbPath       "^PATH:.*"');
	VIM::DoCommand('syntax match fbMark       "^.* <-$"he=e-3');
	unless ($did_syntax_inits) {
		$did_syntax_inits = 1;
		VIM::DoCommand(  'highlight link fbDir        Directory');
		VIM::DoCommand(  'highlight link fbExecutable Type');
		VIM::DoCommand(  'highlight link fbPath       Title');
		VIM::DoCommand(  'highlight link fbSource     PreProc');
		VIM::DoCommand(  'highlight link fbMark       Visual');
	}
	VIM::DoCommand('let b:current_syntax = "fb"');
}

# get a list of the marked indexes (in array context), or
# the number of files marked (in scalar context)
sub get_marked_files {
	return unless defined wantarray;
	my @marks = $fb->marks();
	my $line = VIM::Eval('line(".")');
	if (!@marks && $line < 2) {
		VIM::Msg("No files selected.");
		return;
	}
	if (!@marks) {
		push @marks, $line - 2;
	}
	return @marks if wantarray;
	my $files;
	map {
		$files .= $fb->fileat($_) . " ";
	} @marks;
	$files =~ s/ $//;
	return $files if !wantarray;
}

1;


