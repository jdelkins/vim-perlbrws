" Vim global plugin for empowering perl with several cool features
" Last Change: 2001 Oct 3
" Maintainer: Joel D. Elkins <jde@elkins.cx>

if isdirectory($HOME . "/.vim/jdelib")
	let $MYLIBDIR = $HOME . "/.vim/jdelib"
elseif isdirectory($VIM . "/vimfiles/jdelib")
	let $MYLIBDIR = expand($VIM) . "/vimfiles/jdelib"
endif

if has("perl")
	perl (my $s = VIM::Eval('$MYLIBDIR')) =~ s,\\,/,g; push @INC, $s;
	perl use Carp; use Vim_Buffer; use Vp; use VimFileBrowser; use VimBufList;
	perl require "funcs.pl"
	command! -range          Vp perl &Vp::do_vimperl(<line1>, <line2>)
	command! -range -nargs=+ Vd perl &Vp::do_vp_cmd(<q-args>, <line1>, <line2>)
	command!                 Ve new ~/.vimperl | set syntax=perl
	command! -range -nargs=1 Vt perl &Vp::tie_range(<f-args>, <line1>, <line2>)
endif

"END

