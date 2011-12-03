Perlbrws
========

Author: Joel D. Elkins <joel@elkins.com>.

Yet another filesystem explorer for [Vim](http://www.vim.org/).

I wrote this years ago, when I started diving deeper into Vim, after having
used that fine editor for years in an "out of the box" configuration.
I recently dusted it off and, voila, I'm putting on github for the sake of
posterity.

It's actually a handy little tool, and I used it for years. It got to be too
much of a hassle, however, keeping up with the unstable world of Perl on
windows (especially vim+perl on windows). Eventually I made do with netrw
browsing, even though I like this a lot better.

Requires a Vim installation with `+perl` or `+perl/dyn`. Working configurations
(versions of Vim and Perl) are not known at this point.  It more or less works
with vim-7.3.154 and perl-5.12.4 on my ubuntu box at this time, but I haven't
tested it on other setups.

Basic Usage
-----------

After installation, use `:Perlbrws` to start the browser in the directory of
the file in the current buffer. You can also use `:Perlbrws /foo/bar` to start
browsing in an arbitrary directory. This will open a new window with
a directory listing similar to `ls -l`:

	drwxr-xr-x   6 joel     Domain U     4096 Dec  2 22:59 ./
	drwxr-xr-x   9 joel     JDE Priv     4096 Dec  2 22:35 ../
	drwxr-xr-x   2 joel     Domain U     4096 Dec  2 22:39 ftplugin/
	drwxr-xr-x   2 joel     Domain U     4096 Dec  2 22:52 plugin/
	drwxr-xr-x   2 joel     Domain U     4096 Dec  2 22:39 syntax/

From there, use `j` and `k` (and other normal navigation maps) to move around.
Pressing `<CR>` on a line does something depending on what line you are on when
you press it.

* If it is a directory, navigate to that directory, replacing the contents of
  the buffer with the contents of the new directory.
* If it is a file, then open the file for editing, replacing the window that
  the browser resides in.

There is some logic applied as to how to display the explorer buffer. If you
have unsaved changes in the current buffer, it will split a new window for the
browser. Otherwise it will replace the current window.

Other Commands
--------------

* `c`: prompt on Vim's command line to change directory to an arbitrary
  directory elsewher on the filesystem.
* `C`: issue a `:cd` command to change vim's working directory to the directory
  currently listed in the browser
* `q`: quit the browser and close the window it's in (if it split a window).
* `m`: set a mark on the current file or directory. `M` marks all.
* `d`: delete the marked set of files (or current file if none marked)
* `r`: refresh the listing
* `x`: execute a shell command on the marked files. You are prompted for
  a command. Use `%s` somewhere in that command to insert the target
  filename(s).
* `s`: change the sort order of the listing. (Hit `<tab>` to see the choices.)
* `.`: toggle whether dotfiles are displayed

Bugs
----

* Currently has some issue with directory path elements that contain spaces.
* Although in the past I used this on Windows platforms, I haven't tested it on
  windows in some years.  There are probably a few bugs specific to that
  configuration.
* Pretty slow for how simple it is. It probably should be re-written in ruby
  but I don't know that language at all.
* Antequated and naive VimL style. I think this was written originally in the
  Vim 5 era and updates have been ...err... sporatic and minimalistic.
