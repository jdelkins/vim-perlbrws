" File:        plugin/perlbrws.vim
" Version:     2.0
" Maintainer:  Joel D. Elkins <joel@elkins.com>
" Description:
" Plugin for vim to present a browser window to the user. This is the model
" aspect, with the code that actually does the work.  ftplugin/perlbrws.vim is
" controller, containing key mappings and so forth to provide a user interface.
" syntax/perlbrws.vim contains the code to direct the visual appearance, and so
" implements the view.

" Load Guard                                                               {{{1
if exists("g:loaded_perlbrws") && g:loaded_perlbrws == 1
	finish
endif
let g:loaded_perlbrws = 1

if !has("perl")
	echoerr "Plugin perlbrws.vim requires the +perl feature to be compiled in, disabling"
	finish
endif

" External API                                                             {{{1
command! -nargs=? -complete=dir Perlbrws call perlbrws#enter(<q-args>)

function! perlbrws#enter(...)
	if !a:0 || a:1 == ""
		let goto = expand("%:p:h")
	else
		let goto = a:1
	endif
	call <SID>Enter(goto)
endfunction

" menu definintion
noremenu Plugin.File\ Browser\ (Perl) :Perlbrws<CR>

noremap <unique> <script> <Plug>PerlbrwsGo :call <SID>Go()<CR>
noremap <unique> <script> <Plug>PerlbrwsChdir :ChdirTo<Space>

" **************************************************************************}}}
" Vim_Buffer package                                                       {{{1
" 
" This is so overly complex it is ridiculous but it does seem to work.
" Basically this is a construct that allows tie-ing a Vim buffer to an array,
" so that you can straigthforwardly manipulate the contents of the buffer using
" array manipulation. Nice idea, but in this module all we do is wipe out the
" existing contents and re-write, which could have been done simply enough with
" standard editing commands.
" *****************************************************************************
function s:SetupVimBuffer()
perl <<EOPERL
	package Vim_Buffer;
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
EOPERL
endfunction

" **************************************************************************}}}
" FileBrowser package                                                      {{{1
"
" This package does the acutal work to select the target directory, read the
" target directory, populate an array structure containing details of the files
" therein.  Details stored include filename, and stat info, which is used both
" to ascertain file type (dir, file, symlink, etc) and to show file mode and
" owner/group.  This package Also handles sorting.  Display is done through the
" Vim_Buffer module, by writing the formatted listing into a tied array.
" *****************************************************************************
function s:SetupFileBrowser()
perl <<EOPERL
	package FileBrowser;

	use Carp;
	#use Cwd 'abs_path';
	use POSIX qw{ :sys_stat_h geteuid getegid strftime };
	use strict;
	use vars qw{ %sorttype $slash $root $pathsep $i_marked $i_filename $i_path $i_dispname $i_linkdata $i_linkstat };


	BEGIN {
		if ($^O eq 'MSWin32') { eval "require Win32::Shortcut;"; }
		$i_marked   = 13;  # index of mark indicator
		$i_filename = 14;  # index of filename (tacked at end of stat list)
		$i_path     = 15;  # index of containing directory path
		$i_dispname = 16;  # "name" to display (if link, use "name -> real")
		$i_linkdata = 17;  # index of symlink data
		$i_linkstat = 18;  # index of start of symlink's target stat list
		%sorttype = (# L: straight lexical
			     'L' => '{ $a->[$i_filename] cmp $b->[$i_filename] }',
			     # l: case-insens lexical
			     'l' => '{ uc($a->[$i_filename]) cmp uc($b->[$i_filename]) }',
			     # D: directories first
			     #'D' => '{ (S_ISDIR($b->[2]) <=> S_ISDIR($a->[2])) || ($a->[$i_filename] cmp $b->[$i_filename]) }',
			     'D' => '{ (checkdir($b) <=> checkdir($a)) || ($a->[$i_filename] cmp $b->[$i_filename]) }',
			     # d: directories first - case insens
			     'd' => '{ (checkdir($b) <=> checkdir($a)) || (uc($a->[$i_filename]) cmp uc($b->[$i_filename])) }',
			     # t: sort by mtime
			     't' => '{ (checkdir($b) <=> checkdir($a)) || ($a->[9] <=> $b->[9]) }',
			    );
		if ($^O eq 'MSWin32') {
			$slash   = q{/\\\\};
			$root    = q{([a-zA-Z]:[/\\\\]|/)};
			$pathsep = q{\\};
		} else {
			$slash   = q{/};
			$root    = q{/};
			$pathsep = q{/};
		}
	}

	sub new {
		my $self = {
			CWD  => $ENV{HOME},
			LS   => [],
			LIST => [],
			DOTS => 0,
			SORT => 'd',
			ERRM => '',
		};
		return bless($self);
	}

	# stat all files in a directory, in preparation for listing them
	# Returns: arrayref of strings representing the ``ls -l'' type listing
	sub ls {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		$self->{LS} = [];
		# Read and lstat all files in the directory
		opendir D, $self->{CWD};
		FILE: while (my $f = readdir D) {
			next FILE if (!$self->{DOTS} and $f =~ /^\./ and $f ne '.' and $f ne '..');
			my $checkfile;
			# win32 pukes when you stat C://foo (thinks it's a network access?)
			if ($self->{CWD} =~ m,[$slash]$,) {
				$checkfile = $self->{CWD}.$f;
			} else {
				$checkfile = $self->{CWD}.$pathsep.$f;
			}
			my @stat = lstat($checkfile);
			push @stat, 0, $f, $self->{CWD};                     # mark indicator, filename
			my $linkfile = chk_read_link(\@stat);
			if ($linkfile) {
				my @linkstat = stat($linkfile);
				push @stat, "";                # dispname (placeholder)
				push @stat, $linkfile;         # link filename
				push @stat, @linkstat;         # stat of symlink target
			}
			&redispname(\@stat);                   # compute the displayed name
			push @{$self->{LS}}, \@stat;
		}
		closedir D;
		return $self->rels();
	}

	# regenerate the visual listing array from the stat array (includes sorting the list)
	# Returns: arrayref of strings representing the ``ls -l'' type listing
	sub rels {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		# sort the listing
		eval '@{$self->{LS}} = sort '.$sorttype{$self->{SORT}}.' @{$self->{LS}}';
		# format into a string array like ls -l
		$self->{LIST} = [];
		map {
			push @{$self->{LIST}}, sprintf("%s%s%s%s%s%s%s%s%s%s %3d %-8s %-8s %8d %.12s %s",
						       &ls_ftype($_),                                # file type
						       (&S_IRUSR & $_->[2]) == &S_IRUSR ? 'r' : '-', # r user
						       (&S_IWUSR & $_->[2]) == &S_IWUSR ? 'w' : '-', # w user
						       (&S_IXUSR & $_->[2]) == &S_IXUSR ? 'x' : '-', # x user
						       (&S_IRGRP & $_->[2]) == &S_IRGRP ? 'r' : '-', # r group
						       (&S_IWGRP & $_->[2]) == &S_IWGRP ? 'w' : '-', # w group
						       (&S_IXGRP & $_->[2]) == &S_IXGRP ? 'x' : '-', # x group
						       (&S_IROTH & $_->[2]) == &S_IROTH ? 'r' : '-', # r other
						       (&S_IWOTH & $_->[2]) == &S_IWOTH ? 'w' : '-', # w other
						       (&S_IXOTH & $_->[2]) == &S_IXOTH ? 'x' : '-', # x other
						       $_->[3],                                      # number of hardlinks
						       &ls_getpwuid($_->[4]),                        # owner
						       &ls_getgrgid($_->[5]),                        # group
						       $_->[7],                                      # size in bytes
						       &ls_mtime($_->[9]),                           # modified time, in string
						       $_->[$i_dispname])                            # displayed name
		} @{$self->{LS}};
		return $self->{LIST};
	}

	# Change directory to whereever is indicated. Pukes if
	# a directory is not given.
	# Parameter: absolute or relative path
	# Returns:   0 on failure (probably bad path), 1 on success
	sub cd {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $wd = shift or return $self->{CWD};

		# if relative path, append to our cwd
		if ($wd !~ m,^$root,) {
			$wd = $self->{CWD}.$pathsep.$wd;
		}

		# canonicalize
		$wd = &fixpath($wd);
		#$wd = abs_path($wd);

		# must be absolute path
		if ($wd !~ m,^$root,) {
			$self->{ERRM} = "path resolved to `$wd': not absolute path";
			return 0;
		}

		# make sure it's really a directory
		if (!stat($wd)) {
			$self->{ERRM} = "$wd: file or directory not found.";
			return 0;
		}

		# on Win32, resolve shortcut, then try again
		if ($^O eq 'MSWin32' && $wd =~ /\.lnk$/i) {
			my $s = new Win32::Shortcut($wd);
			my $target = $s->Resolve();
			$s->Close();
			if ($target) {
				return $self->cd($target);
			}
		}

		# make sure target is a directory
		my @s = stat(_);
		if (!S_ISDIR($s[2])) {
			$self->{ERRM} = "$wd: not a directory";
			return 0;
		}
		$self->{ERRM} = '';
		$self->{CWD} = $wd;
		chdir $wd;
		return 1;
	}

	# Grab the (actual) filename at the given index.
	# Parameter: index into current LS
	sub fileat() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $ind = shift;
		my $f = $self->{LS}->[$ind];
		my $file = $f->[$i_filename];
		if ($self->{CWD} =~ m,^$root$,) {
			$file = $self->{CWD} . $file;
		} else {
			$file = $self->{CWD} . $pathsep . $file;
		}
		if ($^O eq 'MSWin32') {
			$file =~ s,/,\\,g;
		}
		return $file;
	}

	# Figure whether the given indexed file is a directory. More than
	# meets the eye, since if the file is a symlink, the target is what
	# is tested.
	# Parameter: index into current LS
	sub isdir() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $ind = shift;
		my $f = $self->{LS}->[$ind];
		#VIM::Msg("isdir: testing index $ind");
		return checkdir($f);
	}

	sub checkdir($) {
		my $f = shift; # stat info arrayref
		if (&islnk($f) && $f->[$i_linkstat]) {
			#VIM::Msg("checkdir: it's a link");
			return S_ISDIR($f->[2 + $i_linkstat]);
		}
		#VIM::Msg("checkdir: about to call S_ISDIR");
		my $rc = S_ISDIR($f->[2]);
		#VIM::Msg("checkdir: S_ISDIR is $rc");
		return  ($rc > 0);
	}

	# Set whether or not to list dot files.
	# Parameter: 1/0
	sub dots() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		return $self->{DOTS} unless @_;
		my $dots = shift;
		$self->{DOTS} = $dots;
	}

	# Set the sort type
	# Parameter: index into @sort
	sub sort() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $sort = shift;
		$self->{SORT} = $sort;
	}

	# Get the last error message from cd()
	sub errm() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		return "Perlbrws: " . $self->{ERRM};
	}

	# Return the number of marked files, or all marks in array context
	sub marks() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		return unless defined wantarray;
		my @marks;
		my $ls = $self->{LS};
		for (my $i = 0; $i <= $#$ls; $i++) {
			my $f = $ls->[$i];
			push @marks, $i if $f->[$i_marked];
		}
		return wantarray ? @marks : (scalar @marks);
	}

	# Check the marked-ness of the given index
	# Parameter: index into LS of file to check
	# Returns: 0 if not marked, 1 if marked
	sub ismarked() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $ind = shift;
		my $ls = $self->{LS};
		my $f = $ls->[$ind];
		confess "Invalid index $ind" if (!$f or $ind > $#$ls);
		return $f->[$i_marked] != 0;
	}

	# Set the mark at the given indexes
	# Parameters: list of indexes to mark (default 0, not what you want)
	sub mark() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $ls = $self->{LS};
		foreach (@_) {
			my $f = $ls->[$_];
			confess "Invalid index $_" if (!$f or $_ > $#$ls);
			$f->[$i_marked] = 1;
			&redispname($f);
		}
	}

	# Clears the mark at the given indexes
	# Parameters: list of indexes to mark (default 0, not what you want)
	sub unmark() {
		ref(my $self = shift) eq 'FileBrowser'
			or confess 'requires an FileBrowser object';
		my $ls = $self->{LS};
		foreach (@_) {
			my $f = $ls->[$_];
			confess "Invalid index $_" if (!$f or $_ > $#$ls);
			$f->[$i_marked] = 0;
			&redispname($f);
		}
	}

	################################
	# non-object subs
	################################

	# This is very subtle, and probably imperfect.
	# Resolve a path to it's canonical form, removing useless parts like /. and /foo/..
	# Also, does some fun magic stuff on rooted paths, while trying to be compatible
	# with win32.
	# Parameter: absolute (possibly-)non-canonical path
	sub fixpath {
		my $path = shift;
		study $path;
		# compress complete segments of /.. into root /
		$path =~ s,^(/+\.\.)+/?$,/,;
		# compress complete segments of /. into root /
		$path =~ s,^(/+\.)+/?$,/,;
		# compress leading segments of /.. into single /
		$path =~ s,^(/+\.\.)+/,/,;
		# compress leading segments of /. into singe /
		$path =~ s,^(/+\.)+/,/,;
		# compress multiple /'s into one
		if ($^O eq "cygwin") {
			$path =~ s,([^^])[$slash]+,$1/,g;
		} else {
			$path =~ s,[$slash]+,/,g;
		}
		# remove segments of foo/..
		$path =~ s,[^/]+/\.\./?,,g;
		# remove segments of /./
		$path =~ s,/\./,/,g;
		# remove trailing segments of /.
		$path =~ s,([$slash]\.)+$,,;
		# remove trailing / if we are not at the root
		$path =~ s,^($root.*)[$slash]$,$1,;
		return $path;
	}

	# recompute the displayed name for the given stat array.
	# Parameter: arrayref, element of $self->{LS}
	sub redispname() {
		my $f = shift;
		my $dispname = $f->[$i_filename];
		if (&islnk($f)) {
			$dispname .= " -> " . $f->[$i_linkdata];
			$dispname .= '/' if S_ISDIR($f->[$i_linkstat + 2]);
			$dispname .= '*' if isexec($f->[$i_linkstat + 2],
						   $f->[$i_linkstat + 4],
						   $f->[$i_linkstat + 5]);
		} else {
			$dispname .= '/' if S_ISDIR($f->[2]);
			$dispname .= '*' if isexec($f->[2], $f->[4], $f->[5]);
		}
		$dispname .= " <-" if $f->[$i_marked];
		$f->[$i_dispname] = $dispname;
	}

	# Return a one-byte string indicative of the file type as in ``ls -l | cut -b1''
	# Parameter: stat arrayref
	sub ls_ftype {
		my $f = shift;   # stat arrayref
		my $m = $f->[2]; # stat[2]
		return 'd' if S_ISDIR($m);
		return '-' if S_ISREG($m);
		return 'c' if S_ISCHR($m);
		return 'b' if S_ISBLK($m);
		return 's' if S_ISFIFO($m);
		# FIXME: how to determine if it's a symlink on HP/UX? same is linux?
		return 'l' if islnk($f);
		return '?';
	}

	# Return a formatted mtime string, as in ``ls -l''
	# Files older than 180 days, or any time in the future, are given the year in lieu of time component
	# Parameter: stat[9]
	sub ls_mtime {
		my $t = shift;
		my $now = time;
		my $output;
		my $delta = $now - $t;
		my $datefmt = '%e';
		$datefmt = '%d' if ($^O eq 'MSWin32');
		$datefmt = '%d' if ($^O eq 'cygwin');	# cygwin uses newlib
		if ($delta < 0 or $delta > 60 * 60 * 24 * 30 * 6) {
			$output = strftime('%b '.$datefmt.'  %Y', localtime $t);
		} else {
			$output = strftime('%b '.$datefmt.' %H:%M', localtime $t);
		}
		return $output;
	}

	# Looks up the user name based on the uid. noop on win32.
	# Parameter: stat[4]
	sub ls_getpwuid {
		my $uid = shift;
		# getpwuid is not implemented on windoze
		return 'nobody' if $^O eq 'MSWin32';
		return scalar substr(getpwuid($uid), 0, 8);
	}

	# Looks up the group name based on the gid. noop on win32.
	# Parameter: stat[5]
	sub ls_getgrgid {
		my $gid = shift;
		# getgrgid is not implemented on windoze
		return 'nobody' if $^O eq 'MSWin32';
		return scalar substr(getgrgid($gid), 0, 8);
	}

	# Pass in stat array, result is whether the file is a symlink.
	# Deep magic, but POSIX.pm doesn't help us here!
	# Parameter: stat arrayref
	sub islnk($) {
		my $f = shift;
		if ($^O eq 'MSWin32' && $f->[$i_filename] =~ /\.lnk$/i) {
			return ($f->[$i_linkdata] ne "");
		} else {
			my $mode = $f->[2];
			return ($mode & 0120000) == 0120000;
		}
	}

	# test for symbolic link and read it
	# Parameter: stat arrayref, with filename at end
	# Returns: link reference or undef if not a link
	sub chk_read_link($) {
		my $f = shift;
		if ($^O eq 'MSWin32' && $f->[$i_filename] =~ /\.lnk$/i) {
			my $l = new Win32::Shortcut($f->[$i_path] . $pathsep . $f->[$i_filename]);
			my $r = $l->Resolve();
			$l->Close();
			return $r; # Note: returns undef on error
		} else {
			if (islnk($f)) {
				return readlink($f->[$i_filename]);
			}
		}
		return undef;
	}

	# Determine if a file is executable by the current user.
	# I think this is correct, but not totally sure.
	# Parameters: stat[2], stat[4], stat[5]
	sub isexec($$$) {
		my ($mode, $uid, $gid) = @_;
		return 0 if !S_ISREG($mode);
		if ($^O eq 'MSWin32') {
			return (&S_IXUSR & $mode) == &S_IXUSR;
		} else {
			return (&S_IXUSR & $mode) == &S_IXUSR if $uid == geteuid();
			return (&S_IXGRP & $mode) == &S_IXGRP if $gid == getegid();
			return (&S_IXOTH & $mode) == &S_IXOTH;
		}
	}

	# Useful only when running inside of VIM. Prints a debugging message,
	# and offers to abort the eval, in which case it punts with confess.
	# Parameter: debug message
	sub DEBUG($) {
		my $msg = shift;
		my $c = VIM::Eval("confirm(\"$msg   Continue?\", \"\&Yes\n\&No\")");
		if ($c == 2) {
			confess "Stopped per user request";
		}
	}
EOPERL
endfunction

" 
function s:SetupVimFileBrowser()
perl <<EOPERL
	package VimFileBrowser;

	#use FileBrowser;
	#use Vim_Buffer;
	use Carp;
	use vars qw{ $fb $dirfile $did_syntax_inits };

	BEGIN {
		$dirfile = "$ENV{TMP}/_dir$$";
		$fb = new FileBrowser;
		$did_syntax_inits = 0;
		if ($^O eq 'MSWin32') {
			$fb->sort('d');
		} else {
			$fb->sort('D');
		}
	}

	##########################################################
	# subs callable from VIM (public subs)
	##########################################################

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
		SWITCH: for ($sort) {
			/l/ && do { $msg = "Sort: lexical (case insens)";            last SWITCH; };
			/L/ && do { $msg = "Sort: lexical (case sens)";              last SWITCH; };
			/d/ && do { $msg = "Sort: directories first (case insens)";  last SWITCH; };
			/D/ && do { $msg = "Sort: directories first (case sens)";    last SWITCH; };
			/t/ && do { $msg = "Sort: mtime";                            last SWITCH; };
		}
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

	# auxilliary function, to be called from vim script, to determine current file name
	# result stored in variable 'curfile'
	sub getcurfile() {
		my $line = VIM::Eval('line(".")');
		VIM::DoCommand("let curfile = '" . $fb->fileat($line - 2) . "'");
	}

	# auxilliary function, to be called from vim script, to determine if current line represents a directory
	# result stored in variable 'isdir'
	sub getisdir() {
		my $line = VIM::Eval('line(".")');
		my $rc = $fb->isdir($line - 2) ? 1 : 0;
		VIM::DoCommand('let curisdir = ' . $rc);
	}

	# change the file browser directory to the given directory.
	# does not affect VIM's current directory
	sub do_chdir_to($) {
		my $d = shift;
		$d = VIM::Eval("expand('$d')");
		#VIM::Msg($d);
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
		VIM::DoCommand('set modifiable');
		@buf = ("PATH: $cwd");
		push @buf, @{$fb->rels()};
		VIM::DoCommand('set ro');
		VIM::DoCommand('set nomodified');
		VIM::DoCommand('set nomodifiable');
		untie @buf;
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
EOPERL
endfunction

" s:Go function                                                            {{{1
"
" Called when the user wants to do the default action with the selected item in
" the browser list
function s:Go()
	" get file to edit
	if &modified
		echoerr "Buffer modified; relisting"
		perl VimFileBrowser::list()
		return
	endif
	let curline = line(".")
	if curline == 1
		" if it's on the first line, this should have been handled by
		" the appropriate command (refer to ftplugin/perlbrws.vim)
		echoerr "The autoload/perlbrws.vim script has a bug"
		return
	endif

	" The following perl calls set VIM variables for us.
	" Specifically, they set curfile to the path of the current
	" file, and isdir to 1 if the selected file (or symlink
	" target) is a directory
	perl VimFileBrowser::getcurfile()
	perl VimFileBrowser::getisdir()

	if curisdir
		exe ":perl VimFileBrowser::do_chdir_to('".curfile."')"
		return
	endif

	" edit the file.
	" Which window to edit in? if previous buffer is
	" not modified, use it
	let listbuf = bufnr(s:dirfile)
	if getbufvar(s:prevbuf, "&mod") || bufwinnr(s:prevbuf) < 0
		topleft new
	else
		exe bufwinnr(s:prevbuf) . "wincmd w"
	endif
	exe "edit " . escape(curfile, ' ')
	set modifiable
	exe listbuf . "bdelete"
	"exe bufwinnr(curfile) . "wincmd w"
endfunction

" s:Enter function                                                         {{{1
"
" Main entry point -- set up the browser window, and invoke the perl code that
" will initialize the listing
function s:Enter(dir)
	let s:dirfile = expand("[Browser]")
	if &filetype != "perlbrws"
		" look for a perlbrws among the open windows
		" credit: code adapted from man.vim ftplugin
		let s:prevwin = winnr()
		let s:prevbuf = bufnr("%")

		" here we are looking for a visible file browser.
		" go to bottom right, save that window number, go to each
		" window (wrapping to upper left corner) and look for browser.
		" if we get back to bottom right, give up and create new
		" window
		wincmd b
		let brwin = winnr()
		if brwin == 1
			topleft new
		else
			exe s:prevwin . "wincmd w"
			while 1
				if &filetype == "perlbrws"
					break
				endif
				wincmd w
				if brwin == winnr()
					topleft new
					break
				endif
			endwhile
		endif
		silent exec "edit " . s:dirfile
		set buftype=nofile noswapfile
		exe ":perl VimFileBrowser::do_chdir_to('" . a:dir . "')"
	endif
	setlocal ft=perlbrws nomod
	setlocal bufhidden=hide
	setlocal nobuflisted
	setlocal nomodifiable
endfunction

" }}}

" define the perl modules
call s:SetupVimBuffer()
call s:SetupFileBrowser()
call s:SetupVimFileBrowser()

" vim:fdm=marker:
