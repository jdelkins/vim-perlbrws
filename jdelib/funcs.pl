# Perl subs useful from within VIM
# Author: Joel D. Elkins <jde@binarts.com>
#
# Note: put inside Vp:: namespace if you want these
# easily available from within the Vp functions
# (see Vp.pm)
#
# If you use Vp.pm, then when these are called,
# @Vp::a refers to the current buffer
# @Vp::b refers to the alternate buffer (if any)
# @Vp::r refers to the range in the current buffer
#
# The implementation of all of the foregoing is complex;
# see ~/.vimrc, Vp.pm, and Vim_Buffer.pm

####################################################
# Java
####################################################

package Vp;
use Carp;

# This is used to translate unquoted text into a quoted
# string.
sub jquote {
	$r[0] =~ /^(\s*)\b/;
	my $s = $1;
	map {
		s/^$s/$&"/;
		s/$/ " +/;
	} @r;
	$r[$#r] =~ s/ \+$/;/;
}

# This is used to translate a multi-line quoted string into
# unquoted text
sub junquote {
	map {
		s/"//g;
		s/ *\+$//;
	} @r;
	$r[$#r] =~ s/ *;$//;
}

# Converts a file type/mode scalar (as described in L<stat>), into a ls -l type
# of description. Doesn't handle the setuid, setgid, and sticky bits, and also
# ignores any file type other than a directory, assuming all others are normal
# files. This is only useful on win32. Maybe.

sub mode_to_string {
	my $mode = shift or confess 'USAGE: mode_to_string($mode), where $mode is from (stat($file))[2]';
	my $oct;
	my $str;
	map { $oct[$_] = ($mode >> (3 * $_)) & 07 } (0..4);
	if ($oct[4] & 04) {
		$str = 'd';
	} else {
		$str = '-';
	}
	foreach $i (2,1,0) {
		if ($oct[$i] & 04) {
			$str .= 'r';
		} else {
			$str .= '-';
		}
		if ($oct[$i] & 02) {
			$str .= 'w';
		} else {
			$str .= '-';
		}
		if ($oct[$i] & 01) {
			$str .= 'x';
		} else {
			$str .= '-';
		}
	}
	return $str;
}

sub filebrowse_filecmp {
	my ($aname, $bname) = ($a->[$#$a], $b->[$#$b]);
	my $aisd = $a->[2] & 040000;
	my $bisd = $b->[2] & 040000;
	if ($aisd == $bisd) {
		return uc($aname) cmp uc($bname);
	} else {
		return $bisd - $aisd;
	}
}

# Reads the current directory and puts the formatted contents in the current buffer.
# Basically only useful for file browser type things, and even then, why not use
# :r!ls (unless of course you're running win32, hence this)
sub filebrowse_readdir {
	my $dir = shift or confess 'USAGE: filebrowse_readdir($dir)';
	my @ftmp;
	my @output;
	opendir D, $dir;
	while (my $f = readdir D) {
		my @stat = stat("$dir/$f");
		push @stat, $f;
		push @ftmp, \@stat;
	}
	closedir D;
	my @fdat = sort filebrowse_filecmp @ftmp; # case insensitive (on win32), directories at top
	foreach my $f (@fdat) {
		push @output, sprintf('%s %10d   %-20s    %s', &mode_to_string($f->[2]), $f->[7], scalar localtime $f->[9], $f->[$#$f]);
	}
	$main::curbuf->Append($main::curbuf->Count(), @output);
}

1;

