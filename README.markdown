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
(versions of Vim and Perl) are not well known at this point.  It more or less
works with the following configurations:

* vim-7.3.154 and perl-5.12.4 on Ubuntu 11.10
* vim-7.3.364 and perl-5.12.3 on Windows 7 x64
  
... but I haven't tested it on other setups at this point.

Basic Usage
-----------

After installation, use `:Perlbrws` to start the browser in the directory of
the file in the current buffer. You can also use `:Perlbrws /foo/bar` to start
browsing in an arbitrary directory. I prefer to map this command to
`<leader>d`, but this mapping is left to the user. However you inoke the
command, the result is that the script will open a window with a directory
listing similar to `ls -lF`:

	PATH: C:/Users/jde.ELKINS/vimfiles/bundle/perlbrws
	drwxrwxrwx   1 nobody   nobody          0 Dec 02 23:56 ./
	drwxrwxrwx   1 nobody   nobody          0 Dec 02 23:54 ../
	drwxrwxrwx   1 nobody   nobody          0 Dec 02 23:54 ftplugin/
	drwxrwxrwx   1 nobody   nobody          0 Dec 02 23:56 plugin/
	drwxrwxrwx   1 nobody   nobody          0 Dec 02 23:54 syntax/
	-rw-rw-rw-   1 nobody   nobody       3507 Dec 02 23:54 README.markdown

From there, you can use `j`, `k`, and other normal navigation maps to move
around.  I often use `/` to search for a desired location. Pressing `<CR>` on
a line does something intuitive depending on what line the cursor is on when
you press it.

* If the cursor is on a directory, navigate to that directory, replacing the
  contents of the buffer with the contents of the new directory.
* If the cursor is on a file, then open the file for editing, replacing the
  window that the browser resides in.
* If the cursor is on the very top line (which shows the current directory), it
  will invoke a prompt on the Vim command line to change to a different,
  arbitrary directory.

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
* `<tab>`: jumps to the first character of the filename in the listing, staying
  on the current line.

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
