
"*****************************************************************************
" CVS Mode
"*****************************************************************************
" Purpose: facilitate cvs managment of source files within vim
"          sort of like emacs VC mode
" Author:  Joel D. Elkins <jde@elkins.cx>
" Copyright: (c) 1999 Joel D. Elkins. All rights reserved.
"
"*****************************************************************************
" COPYING (see the full GPL license at http://www.gnu.org/copyleft/gpl.html)
"*****************************************************************************
" This program is free software; you can redistribute it and/or
" modify it under the terms of the GNU General Public License
" as published by the Free Software Foundation; either version 2
" of the License, or (at your option) any later version.
" 
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
" 
" You should have received a copy of the GNU General Public License
" along with this program; if not, write to the Free Software
" Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
"*****************************************************************************

" alter this to taste
let _cvs_cmd = "cvs -z3"

" set to nonzero if running in dos-like environment
let _cvs_dos = 0

" on the command line, how do we separate one command from the next?
" (only used on Unix)
let _cvs_pathsep = "; "

" make a multi-line command.
" this is ugly in the win32 case, since win32 isn't good.
" (it creates a batch file with the command lines in it)
function! CvsMakeCommandLine(...)
	let i = 1
	let cmd = ""
	let savech = &cmdheight
	let &cmdheight = 5
	if g:_cvs_dos
		let tn = CvsTempname()
		" make the temp file an MS-DOS batch file
		let bat = fnamemodify(tn, ":r") . ".bat"
		exe "redir! >" . bat
		echon "\r\n"
	endif
	while i <= a:0
		exe "let c = a:" . i
		if g:_cvs_dos
			echon c
			echon "\r\n"
		elseif cmd == ""
			let cmd = c
		else
			let cmd = cmd . g:_cvs_pathsep . c
		endif
		let i = i + 1
	endwhile
	if g:_cvs_dos
		echon "del ".bat."\r\n"
		redir END
		" on Dos, the command is the batch file
		let cmd = bat
	endif
	let &cmdheight = savech
	return cmd
endfunction

" Utility
" Save the current buffer if it has been modified, prompting the user
" Return codes:
"  0 -> save done or unnecessary
"  1 -> cancel the operation - DO NOTHING ELSE
"  2 -> user opted not to save, continue if possible
function! CvsSaveIfModifed() abort
	if &modified
		let choice = confirm("Buffer modified. Save first?", "Yes\nNo\nCancel", 0, "Question")
		"echo "Choice: " choice
		if choice == 0 || choice == 3 || choice == "Cancel"
			return 1
		elseif choice == 1 || choice == "Yes"
			write
		elseif choice == 2 || choice == "No"
			return 2
		endif
	endif
	return 0
endfunction

" Get a unique temp file name. Wrapper around builtin tempname()
function! CvsTempname()
	let tn = tempname()
	"in win32, tempname() leaves a turd file
	call delete(tn)
	return tn
endfunction

" Get the temp file directory
function! GetTempDir() abort
	let tn = CvsTempname()
	let td = fnamemodify(tn, ":p:h")
	return td
endfunction

" Check to ensure that the current buffer's file
" is in a directory that has a subdirectory named CVS
" returns:
"   * the name of the file's directory if it contains a CVS sub
"   * 1 if the file's directory does not contain a CVS sub
" note that this construct is designed so that you can use a
" simple test like
"   :if CvsCheckDirectory()
"      ...error...
"   :else
"      ...process..
"   :endif
" (This is okay because vim interprets the numerical value
"  of strings to be 0 if don't start with a number <= possible gottcha.)
function! CvsCheckDirectory()
	let dir = expand("%:p:h")
	if !isdirectory(dir . "/CVS")
		return 1
	endif
	return dir
endfunction

" Report an error in the ErrorMsg highlight
function! CvsError(emsg)
	echohl ErrorMsg
	echo   a:emsg
	echohl None
endfunction

" Run a "cvs log" on one file, or all in a directory
" params:
"   * lopts - log options (e.g. "-h")
"   * fn    - file name (use "" for all files in the directory)
function! CvsLog(lopts, fn) abort
	let dir = CvsCheckDirectory()
	if dir
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	let tn  = CvsTempname()
	let cmd = CvsMakeCommandLine("cd " . dir, g:_cvs_cmd . " log " . a:lopts . " " . a:fn . " >> " . tn)
	"echo cmd
	exe ':!' cmd
	exe "new" tn
	call delete(tn)
endfunction

" Run a "cvs diff" on one file, or all in a directory
" params:
"   * fn    - file name (use "" for all files in the directory)
function! CvsDiff(fn) abort
	let dir = CvsCheckDirectory()
	if dir
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	let rc = CvsSaveIfModifed()
	else
	if rc == 1
		return
	endif
	let tn  = CvsTempname()
	let cmd = CvsMakeCommandLine("cd " . dir, g:_cvs_cmd . " diff -u " . a:fn . " >> " . tn)
	exe ':!' cmd
	exe "new" tn
	call delete(tn)
	if exists("*SetSyn")
		call SetSyn("diff")
	endif
endfunction

" Run a "cvs status" on one file, or all in a directory
" params:
"   * fn    - file name (use "" for all files in the directory)
function! CvsStatus(fn) abort
	let dir = CvsCheckDirectory()
	if dir
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	let rc = CvsSaveIfModifed()
	if rc == 1
		return
	endif
	let tn = CvsTempname()
	let cmd = CvsMakeCommandLine("cd " . dir, g:_cvs_cmd . ' status ' . a:fn . " >> " . tn)
	exe ':!' cmd
	exe "new" tn
	call delete(tn)
endfunction

" Run a "cvs update" on one file, or all in a directory
" params:
"   * n     - cvs options (e.g., "-n" for a fake update)
"   * fn    - file name (use "" for all files in the directory)
function! CvsUpdate(n, fn) abort
	let dir = CvsCheckDirectory()
	if dir
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	let rc = CvsSaveIfModifed()
	if rc == 1
		return
	endif
	let tn = CvsTempname()
	let cmd = CvsMakeCommandLine("cd " . dir, g:_cvs_cmd . " " . a:n . " update " . a:fn . " >> " . tn)
	exe ':!' cmd
	exe "new" tn
	call delete(tn)
endfunction

" Run a "cvs add" on one file, or all in a directory
" params:
"   * fn    - file name (use "" for all files in the directory)
function! CvsAdd(fn) abort
	let dir = CvsCheckDirectory()
	if dir
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	let rc = CvsSaveIfModifed()
	if rc == 1
		return
	endif
	let tn = CvsTempname()
	let cmd = CvsMakeCommandLine("cd " . dir, g:_cvs_cmd . " add " . a:fn . " >> " . tn)
	exe ':!' cmd
	exe "new" tn
	call delete(tn)
endfunction

" Run a "cvs commit" on some files
" params: files to commit, none implies the whole directory
" This function just sets things up for editing the commit log
" The actual commit happens in CvsCommitFini(), which gets
" run when the user hits <C-X><C-X> in the log window
function! CvsCommit(...) abort
	" process args into a space-separated list, which is
	" stashed in the global variable _cvs_currentfiles
	" for use in CvsCommitFini()
	let g:_cvs_currentfiles = ""
	let i = 1
	while i <= a:0
		exe "let f = a:" . i
		let g:_cvs_currentfiles = g:_cvs_currentfiles . " " . f
		let i = i + 1
	endwhile
	" file must be under cvs control
	let g:_cvs_currentdir = CvsCheckDirectory()
	if (g:_cvs_currentdir)
		call CvsError(expand("%") . " is evidently not under CVS control.")
		return
	endif
	" file must be saved
	let rc = CvsSaveIfModifed()
	if rc == 1
		return
	elseif rc == 2
		echohl ErrorMsg
		echo "Cannot continue without saving."
		echohl None
	endif
	" who am i
	let u = $USER
	if !strlen(u)
		let u = $LOGNAME
	endif
	" It is sometimes useful to reuse log files across several commits. Therefore
	" we concoct this quasi-unique log file rather than using CvsTempname()
	let g:_cvs_logfile = GetTempDir() . "/cvs-" . hostname() . "-" . u . ".log"
	echo "CVS: Hit <C-X><C-X> when finished"
	exe ":new" g:_cvs_logfile
	nnoremap <C-X><C-X> :call CvsCommitFini()<CR>
endfunction

" Runs the actual "cvs commit", assuming the user has finished entering the log message
" * assumes that the log buffer is somewhere in memory still
" * you don't have to save the log buffer first, this will write it
function! CvsCommitFini() abort
	exe ":b" g:_cvs_logfile
	let &ff = "unix"
	write
	hide
	let cmd = CvsMakeCommandLine("cd " . g:_cvs_currentdir, g:_cvs_cmd . ' commit -F "' . g:_cvs_logfile . '" ' . g:_cvs_currentfiles)
	"echo cmd
	exe ':!' cmd
	edit %
	nunmap <C-X><C-X>
endfunction

" Some key mappings - maybe sort of reminiscent of emacs - customize to taste
nnoremap <C-X>vl :call CvsLog("", expand("%:t"))<CR>
nnoremap <C-X>vL :call CvsLog("", "")<CR>
nnoremap <C-X>vh :call CvsLog("-h", expand("%:t"))<CR>
nnoremap <C-X>vH :call CvsLog("-h", "")<CR>
nnoremap <C-X>vc :call CvsCommit(expand("%:t"))<CR>
nnoremap <C-X>vC :call CvsCommit()<CR>
nnoremap <C-X>v= :call CvsDiff(expand("%:t"))<CR>
nnoremap <C-X>v+ :call CvsDiff("")<CR>
nnoremap <C-X>vs :call CvsStatus(expand("%:t"))<CR>
nnoremap <C-X>vS :call CvsStatus("")<CR>
nnoremap <C-X>vu :call CvsUpdate("-n", expand("%:t"))<CR>
nnoremap <C-X>vU :call CvsUpdate("-n", "")<CR>
nnoremap <C-X>va :call CvsAdd(expand("%:t"))<CR>
nnoremap <C-X>vA :call CvsAdd("")<CR>

"END


