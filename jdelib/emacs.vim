
" ========================================================================
" Key mappings for emacs compatibility
" ========================================================================
" some of these I have commented out because I no longer find them useful 8-P

"nnoremap <C-X>o     <C-W><C-W>
"nnoremap <C-X>2     :split<CR>
"nnoremap <C-X>1     <C-W>o
"nnoremap <C-X>k     :confirm q<CR>
"nnoremap <C-X><C-C> :confirm qa<CR>
"if has("gui_running") && has("dialog_gui")
"	nnoremap <C-X><C-F> :browse confirm e<CR>
"else
"	nnoremap <C-X><C-F> :exe ":normal :e " expand('%:p:h') . "/" <CR>
"endif
"nnoremap <C-X><C-S> :w<CR>
"nnoremap <C-X>b     :ls<CR>:b
inoremap <M-/>      <C-P>

" some emacs-ness in command mode
" (see the emacs-keys help section)
cnoremap <C-G>      <C-C>
cnoremap <C-A>      <Home>
cnoremap <C-B>      <Left>
cnoremap <C-D>      <Del>
cnoremap <C-E>      <End>
cnoremap <C-F>      <Right>
cnoremap <C-N>      <Down>
cnoremap <C-P>      <Up>
cnoremap <Esc><C-B> <S-Left>
cnoremap <Esc><C-F> <S-Right>
cnoremap <M-B>      <S-Left>
cnoremap <M-F>      <S-Right>
cnoremap <M-BS>     <C-W>

" some emacs-ness in insert mode
"inoremap <C-G>      <Esc>
inoremap <C-A>      <Home>
inoremap <C-B>      <Left>
inoremap <C-D>      <Del>
inoremap <C-E>      <End>
inoremap <C-F>      <Right>
"inoremap <C-N>      <Down>
"inoremap <C-P>      <Up>
"inoremap <C-K>      <Esc><Right>C
inoremap <M-B>      <S-Left>
inoremap <M-F>      <S-Right>
inoremap <M-BS>     <C-W>
