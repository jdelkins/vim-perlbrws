" Vim filetype plugin file
" Language:	perlbrws
" Maintainer:	Joel Elkins <jde@elkins.cx>
" Last Change:	2004 Jul 15
"
" This plugin implements a dired-esque file browser, that uses perl code to
" generate the listing.
"
" See also:
" plugin/perlbrws.vim
" ftdetect/perlbrws.vim
" syntax/perlbrws.vim

" If 'filetype' isn't "perlbrws", the file may have been loaded directly --
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
nmap <buffer> <SID>Action :call <SID>Remap()<CR><SID>CRMap
function! s:Remap()
	if line(".") == 1
		nmap <buffer> <SID>CRMap <SID>Chdir
	else
		nmap <buffer> <SID>CRMap <SID>Go
	endif
endf
nmap <SID>Go <Plug>PerlbrwsGo
" Note: the follwoing map has an intentional trailing space on the rhs
nmap <SID>Chdir :ChdirTo 

" Various file actions
" TODO: these should probably call Plugin functions, not perl code
nnoremap <buffer> <Tab> 56\|
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
nnoremap <buffer> sD :perl VimFileBrowser::set_sort("D")<CR>
nnoremap <buffer> sd :perl VimFileBrowser::set_sort("d")<CR>
nnoremap <buffer> sL :perl VimFileBrowser::set_sort("L")<CR>
nnoremap <buffer> sl :perl VimFileBrowser::set_sort("l")<CR>
nnoremap <buffer> st :perl VimFileBrowser::set_sort("t")<CR>
nnoremap <buffer> d :perl VimFileBrowser::do_delete()<CR>

" the follwoing command will change the browser directory, and will
" tab-complete for directories
command -buffer -nargs=1 -complete=dir ChdirTo :perl VimFileBrowser::do_chdir_to(<q-args>)<CR>

" disable (most?) buffer-editing normal commands -- we try to make it hard to
" change the buffer contents...

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
nnoremap <buffer> s <Esc>
nnoremap <buffer> X <Esc>

