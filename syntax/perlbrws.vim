" Vim syntax file
" Language:	perlbrws
" Maintainer:	Joel Elkins <jde@elkins.cx>
" Last Change:	2004 Jul 15
"
" $Header$
"
" This 'language' is for a file browser I wrote, which uses some perl code to
" generate the listing. This syntax file assumes quite a lot about the the
" format of that listing

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

" source code file extensions: c\|h\|cpp\|cp\|pl\|pm\|java\|html\|sql\|sh\|ksh\|vim\|tex\|mp
syntax case match
syntax match perlbrwsDir        "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>/$"hs=s+13,he=e-1
syntax match perlbrwsDir        "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>/$"hs=s+13,he=e-1
syntax match perlbrwsExecutable "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>\*$"hs=s+13,he=e-1
syntax match perlbrwsExecutable "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\( -> .*\)\=\>\*$"hs=s+13,he=e-1
syntax match perlbrwsSource     "\u\l\l [0-3 ]\d \d\d:\d\d \<[ -./[:alnum:]_~]\+\.\(c\|h\|cpp\|cp\|pl\|pm\|java\|html\|sql\|sh\|ksh\|vim\|tex\|mp\)\>$"hs=s+13
syntax match perlbrwsSource     "\u\l\l [0-3 ]\d  \d\d\d\d \<[ -./[:alnum:]_~]\+\.\(c\|h\|cpp\|cp\|pl\|pm\|java\|html\|sql\|sh\|ksh\|vim\|tex\|mp\)\>$"hs=s+13
syntax match perlbrwsPath       "^PATH:.*"
syntax match perlbrwsMark       "^.* <-$"he=e-3

highlight default link perlbrwsDir        Directory
highlight default link perlbrwsExecutable Type
highlight default link perlbrwsPath       Title
highlight default link perlbrwsSource     PreProc
highlight default link perlbrwsMark       Visual

let b:current_syntax = "perlbrws"
