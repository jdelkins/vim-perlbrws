" Vim filetype plugin file
" Language:	perlbrws
" Maintainer:	Joel Elkins <jde@elkins.cx>
" Last Change:	2004 Jul 15
"
" $Header$
"
" This plugin implements a dired-esque file browser, that uses perl code to
" generate the listing.
"
" See also:
" plugin/perlbrws.vim
" ftdetect/perlbrws.vim
" syntax/perlbrws.vim

" If 'filetype' isn't "perlbrws", the script may have been loaded directly --
" don't do anything in that case because we don't want to screw up a regular
" file!
if &filetype != "perlbrws"
	finish
endif

" only need to do this once for the buffer
if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

" Add mappings. Note that I'm ignoring "no_plugin_maps" because this
" plugin is useless without the mappings

" The following rather subtle chain involves changing the behavior of
" <CR> or <2-LeftMouse> depending on which line of the file is active:
" On the first line, we want to change directories, otherwise navigate
" to the selected file.
nmap <buffer> <2-LeftMouse> <SID>Action
nmap <buffer> <CR> <SID>Action
nmap <buffer> <SID>Action :call <SID>Remap()<CR><SID>ActionMap
function! s:Remap()
	if line(".") == 1
		nmap <buffer> <SID>ActionMap <SID>Chdir
	else
		nmap <buffer> <SID>ActionMap <SID>Go
	endif
endf
nmap <SID>Go <Plug>PerlbrwsGo
" Note: the follwoing map has an intentional trailing space on the rhs
nmap <SID>Chdir :ChdirTo 

" Various file actions
" TODO: these should probably call Plugin functions, not perl code
nnoremap <buffer> <Tab> 56<Bar>
nnoremap <buffer> q :bd!<CR>
nnoremap <buffer> . :perl VimFileBrowser::dots_toggle()<CR>
nnoremap <buffer> m :perl VimFileBrowser::mark_toggle()<CR>
nnoremap <buffer> u :perl VimFileBrowser::mark_toggle()<CR>
nnoremap <buffer> M :perl VimFileBrowser::mark_all()<CR>
nnoremap <buffer> U :perl VimFileBrowser::unmark_all()<CR>
nnoremap <buffer> r :perl VimFileBrowser::list()<CR>
" Note: the follwoing map has an intentional trailing space on the rhs
nnoremap <buffer> c :ChdirTo 
nnoremap <buffer> C :perl VimFileBrowser::do_vim_cd_to_fb_cwd()<CR>
nnoremap <buffer> x :perl VimFileBrowser::do_exec()<CR>
" Note: the follwoing map has an intentional trailing space on the rhs
nnoremap <buffer> s :SetSort 
nnoremap <buffer> d :perl VimFileBrowser::do_delete()<CR>

" the follwoing command will change the browser directory, and will
" tab-complete for directories
command -buffer -nargs=1 -complete=dir ChdirTo :perl VimFileBrowser::do_chdir_to(<q-args>)

" the following command sets the sort type
command -buffer -nargs=1 -complete=custom,<SID>ListSortTypes SetSort :call <SID>SetSort(<q-args>)

function! s:ListSortTypes(A,L,P)
	return "directory-caseinsens\ndirectory-casesens\nlex-caseinsens\nlex-casesens\nmodtime"
endfunction

function! s:SetSort(s)
	if a:s == "directory-caseinsens"
		let type = "d"
	elseif a:s == "directory-casesens"
		let type = "D"
	elseif a:s == "lex-caseinsens"
		let type = "l"
	elseif a:s == "lex-casesens"
		let type = "L"
	elseif a:s == "modtime"
		let type = "t"
	else
		echoerr "Invalid sort method"
	endif
	exe "perl VimFileBrowser::set_sort('" . type . "')"
endfunction

" disable (most?) buffer-editing normal commands -- we try to make it hard to
" change the buffer contents...
"
" Note: this is pretty much obsolete, since the buffer should be set by the
" plugin to be 'nomodifiable' but, it's nicer to just get a friendly beep
" instead of the "buffer not modifiable" error message.

nnoremap <buffer> A <Esc>
nnoremap <buffer> a <Esc>
nnoremap <buffer> D <Esc>
nnoremap <buffer> i <Esc>
nnoremap <buffer> J <Esc>
nnoremap <buffer> o <Esc>
nnoremap <buffer> O <Esc>
nnoremap <buffer> D <Esc>
nnoremap <buffer> p <Esc>
nnoremap <buffer> P <Esc>
nnoremap <buffer> X <Esc>

