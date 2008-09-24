" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim. 
"
" DESCRIPTION:
" USAGE:
"   First define your mapping in the usual way:
"	nnoremap <silent> <Leader>v :version<CR>
"   Then make the mapping repeatable; this will redefine the original mapping
"   and insert the call to repeat#set() at the end. 
"	silent! call repeatableMapping#makeRepeatable('nnoremap <silent>', '<Leader>v', 'Test2')
"   The processing requires the following information:
"   - The original mapping command (for the map-mode, whether "noremap" or not,
"     any optional map-arguments like "<buffer>"). 
"   - The mapping's lhs (i.e. keys that invoke the mapping). 
"   - A unique name for the intermediate <Plug> mapping that needs to be created
"     so that repeat.vim can invoke it. 
"
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
"	002	25-Sep-2008	BF: '|' must be escaped, or the map command will
"				end prematurely.  
"	001	24-Sep-2008	file creation

let s:save_cpo = &cpo
set cpo&vim

function! repeatableMapping#makeRepeatable( mapcmd, lhs, mapname, ... )
    let l:plugname = '<Plug>' . a:mapname
    let l:mapmode = (a:mapcmd =~# '^\w\%(nore\)\?map' ? strpart(a:mapcmd, 0, 1) : '')

    let l:rhs = maparg(a:lhs, l:mapmode)
    let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')	" '|' must be escaped, or the map command will end prematurely.  
    if l:rhs =~? ':.*<CR>$'
	let l:rhs = substitute(l:rhs, '\c<CR>$', '', '')
	let l:cmdJoiner = '<Bar>'
    else
	let l:cmdJoiner = ':'
    endif

    let l:plugMapping = a:mapcmd . ' ' . l:plugname . ' ' . l:rhs . 
    \	l:cmdJoiner . 'silent! call repeat#set("\' . l:plugname . '"' . (a:0 ? ', ' . a:1 : '') . ')<CR>'
"****D echomsg l:plugMapping
    execute l:plugMapping

    let l:lhsMapping = substitute(a:mapcmd, 'noremap', 'map', '')  . ' ' . a:lhs . ' ' . l:plugname
"****D echomsg l:lhsMapping
    execute l:lhsMapping
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
