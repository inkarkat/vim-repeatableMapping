" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim. 
"
" DESCRIPTION:
" USAGE:
" INSTALLATION:
" DEPENDENCIES:
"   - vimscript #2136 repeat.vim autoload script
"
" CONFIGURATION:
" INTEGRATION:
" LIMITATIONS:
" ASSUMPTIONS:
" KNOWN PROBLEMS:
" TODO:
"
" Copyright: (C) 2008 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	001	00-Jan-2008	file creation

let s:save_cpo = &cpo
set cpo&vim

function! repeatableMapping#map( mapcmd, mapname, lhs, rhs, ... )
    let l:plugname = '<Plug>' . a:mapname

    if a:rhs =~? ':.*<CR>$'
	let l:rhs = substitute(a:rhs, '\c<CR>$', '', '')
	let l:cmdJoiner = '<Bar>'
    else
	let l:rhs = a:rhs
	let l:cmdJoiner = ':'
    endif

    let l:plugMapping = a:mapcmd . ' ' . l:plugname . ' ' . l:rhs . 
    \	l:cmdJoiner . 'silent! call repeat#set("\' . l:plugname . '"' . (a:0 ? ', ' . a:1 : '') . ')<CR>'
echomsg l:plugMapping
    execute l:plugMapping

    let l:lhsMapping = substitute(a:mapcmd, 'noremap', 'map', '')  . ' ' . a:lhs . ' ' . l:plugname
echomsg l:lhsMapping
    execute l:lhsMapping
endfunction

"call repeatableMapping#map('nnoremap', 'Test1', '<Leader><Leader>', 'iTest1<CR>')
"call repeatableMapping#map('nnoremap', 'Test2', '<Leader>v', ':version<CR>')
"call repeatableMapping#map('nnoremap', 'Test3', '<Leader>t', ':set wrap!<CR>', -1)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
