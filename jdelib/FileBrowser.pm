
package FileBrowser;

use Carp;
#use Cwd 'abs_path';
use POSIX qw{ :sys_stat_h geteuid getegid strftime };
use strict;
use vars qw{ %sorttype $slash $root $i_marked $i_filename $i_dispname $i_linkdata $i_linkstat };


BEGIN {
	$i_marked   = 13;  # index of mark indicator
	$i_filename = 14;  # index of filename (tacked at end of stat list)
	$i_dispname = 15;  # "name" to display (if link, use "name -> real")
	$i_linkdata = 16;  # index of symlink data
	$i_linkstat = 17;  # index of start of symlink's target stat list
	%sorttype = (# L: straight lexical
		     'L' => '{ $a->[$i_filename] cmp $b->[$i_filename] }',
		     # l: case-insens lexical
		     'l' => '{ uc($a->[$i_filename]) cmp uc($b->[$i_filename]) }',
		     # D: directories first
		     'D' => '{ (S_ISDIR($b->[2]) <=> S_ISDIR($a->[2])) || ($a->[$i_filename] cmp $b->[$i_filename]) }',
		     # d: directories first - case insens
		     'd' => '{ (S_ISDIR($b->[2]) <=> S_ISDIR($a->[2])) || (uc($a->[$i_filename]) cmp uc($b->[$i_filename])) }',
		     # t: sort by mtime
		     't' => '{ (S_ISDIR($b->[2]) <=> S_ISDIR($a->[2])) || ($a->[9] <=> $b->[9]) }',
		    );
	if ($^O eq 'MSWin32') {
		$slash = q{/\\\\};
		$root  = q{([a-zA-Z]:[/\\\\]|/)};
	} else {
		$slash = q{/};
		$root  = q{/};
	}
}

sub new {
	my $self = {
		CWD  => `pwd`,
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
			$checkfile = $self->{CWD}."/".$f;
		}
		my @stat = lstat($checkfile);
		push @stat, 0, $f;                     # mark indicator, filename
		if (&islnk($stat[2])) {
			my $ldat = readlink($checkfile);
			my @linkstat = stat($checkfile);
			my $dispname = "$f -> $ldat";
			push @stat, "";                # dispname (placeholder)
			push @stat, $ldat;             # link data
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
					       &ls_ftype($_->[2]),                           # file type
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
		$wd = "$self->{CWD}/$wd";
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
	my @s = stat(_);
	if (!S_ISDIR($s[2])) {
		$self->{ERRM} = "$wd: not a directory";
		return 0;
	}
	$self->{ERRM} = '';
	$self->{CWD} = $wd;
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
		$file = $self->{CWD} . '/' . $file;
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
	if (&islnk($f->[2]) && $f->[$i_linkstat]) {
		return S_ISDIR($f->[2 + $i_linkstat]);
	}
	return S_ISDIR($f->[2]);
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
	return $self->{ERRM};
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
	if (&islnk($f->[2])) {
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
# Parameter: stat[2]
sub ls_ftype {
	my $m = shift;
	return 'd' if S_ISDIR($m);
	return '-' if S_ISREG($m);
	return 'c' if S_ISCHR($m);
	return 'b' if S_ISBLK($m);
	return 's' if S_ISFIFO($m);
	# FIXME: how to determine if it's a symlink on HP/UX? same is linux?
	return 'l' if islnk($m);
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

# Pass in mode, result is whether the file is a symlink.
# Deep magic, but POSIX.pm doesn't help us here!
# Parameter: stat[2]
sub islnk($) {
	my $mode = shift;
	return ($mode & 0120000) == 0120000;
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

1;


