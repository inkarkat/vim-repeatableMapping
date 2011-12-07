" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim. 
"
" DEPENDENCIES:
"   - vimscript #2136 repeat.vim autoload script
"   - visualrepeat plugin (optional). 
"
" Copyright: (C) 2008-2011 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	005	06-Dec-2011	<Plug>ReenterVisualMode: If [count] is given,
"				the size is multiplied accordingly. 
"	004	30-Sep-2011	Automatically map <Plug>-mapping with <silent>
"				to avoid showing the repeat invocation. 
"	003	17-Mar-2011	Factor out s:MakePlugMappingWithRepeat(). 
"				Add
"				repeatableMapping#makePlugMappingRepeatable()
"				for the case when a <Plug> mapping already
"				exists and just needs the repeat#set() appended. 
"	002	25-Sep-2008	BF: '|' must be escaped, or the map command will
"				end prematurely.  
"	001	24-Sep-2008	file creation
let s:save_cpo = &cpo
set cpo&vim

function! s:ReenterVisualMode()
    if visualmode() ==# 'V'
	" In linewise visual mode, the repeat command is invoked for each
	" individual line. Thus, we only need to select the current line. 
	return 'V'
    elseif getpos('.') == getpos("'<") || getpos('.') == getpos("'>")
	return 'gv'
    else
	" A normal-mode repeat of the visual mapping is triggered by repeat.vim.
	" It establishes a new selection at the cursor position, of the same
	" mode and size as the last selection.
	"   If [count] is given, the size is multiplied accordingly. This has
	"   the side effect that a repeat with [count] will persist the expanded
	"   size, which is different from what the normal-mode repeat does (it
	"   keeps the scope of the original command). 
	return v:count1 . 'v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')
	" For ':set selection=exclusive', the final character must be
	" re-included with <Space>, but only if this is not linewise visual
	" mode; in that case, the <Space> would add the next line in case the
	" last selected line is empty.  
    endif
endfunction
nnoremap <silent> <expr> <Plug>ReenterVisualMode <SID>ReenterVisualMode()

function! s:GetRhsAndCmdJoiner( lhs, mapmode )
    let l:rhs = maparg(a:lhs, a:mapmode)
    let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')	" '|' must be escaped, or the map command will end prematurely.  
    if l:rhs =~? ':.*<CR>$'
	let l:rhs = substitute(l:rhs, '\c<CR>$', '', '')
	let l:cmdJoiner = '<Bar>'
    else
	let l:cmdJoiner = ':'
    endif

    return [l:rhs, l:cmdJoiner]
endfunction

function! s:MakePlugMappingWithRepeat( mapcmd, lhs, plugname, ... )
    let l:mapmode = (a:mapcmd =~# '^\w\%(nore\)\?map' ? a:mapcmd[0] : '')

    let [l:rhs, l:cmdJoiner] = s:GetRhsAndCmdJoiner(a:lhs, l:mapmode)

    let l:plugMapping = a:mapcmd . ' <silent> ' . a:plugname . ' ' . l:rhs . 
    \	l:cmdJoiner . 'silent! call repeat#set("' . 
    \	(l:mapmode ==# 'v' ? '\<Plug>ReenterVisualMode' : '') . 
    \	'\' . a:plugname .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<CR>'
"****D echomsg l:plugMapping
    execute l:plugMapping
endfunction

function! repeatableMapping#makeRepeatable( mapcmd, lhs, mapname, ... )
    let l:plugname = '<Plug>' . a:mapname
    call call('s:MakePlugMappingWithRepeat', [a:mapcmd, a:lhs, l:plugname] + a:000)

    let l:lhsMapping = substitute(a:mapcmd, 'noremap', 'map', '')  . ' ' . a:lhs . ' ' . l:plugname
"****D echomsg l:lhsMapping
    execute l:lhsMapping
endfunction

function! repeatableMapping#makePlugMappingRepeatable( mapcmd, mapname, ... )
    call call('s:MakePlugMappingWithRepeat', [a:mapcmd, a:mapname, a:mapname] + a:000)
endfunction

function! s:RepeatSection( nrepeat, vrepeat )
    return
    \	'silent! call repeat#set("' .
    \	'\' . a:nrepeat .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<Bar>silent! call visualrepeat#set("' .
    \	'\' . a:vrepeat .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<CR>'

endfunction
function! repeatableMapping#makeCrossRepeatable( nmapcmd, nlhs, nmapname, vmapcmd, vlhs, vmapname, ... )
    if a:nmapname ==# a:vmapname | throw 'ASSERT: nmapname and vmapname must be different' | endif

    let l:nplugname = '<Plug>' . a:nmapname
    let l:vplugname = '<Plug>' . a:vmapname

    let [l:nrhs, l:ncmdJoiner] = s:GetRhsAndCmdJoiner(a:nlhs, 'n')
    let [l:vrhs, l:vcmdJoiner] = s:GetRhsAndCmdJoiner(a:vlhs, 'v')

    let l:nplugMapping = a:nmapcmd . ' <silent> ' . l:nplugname . ' ' .
    \	l:nrhs .
    \	l:ncmdJoiner .
    \	s:RepeatSection(l:nplugname, l:vplugname)

    let l:vplugMapping = a:vmapcmd . ' <silent> ' . l:vplugname . ' ' .
    \	l:vrhs .
    \	l:vcmdJoiner .
    \	s:RepeatSection(l:vplugname, l:vplugname)

    let l:rplugMapping = a:nmapcmd . ' <silent> ' . l:vplugname . ' ' .
    \	":<C-u>execute 'normal!' v:count1 . 'v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')<CR>" .
    \	l:vrhs .
    \	l:vcmdJoiner .
    \	s:RepeatSection(l:vplugname, l:vplugname)

    execute l:nplugMapping
    execute l:vplugMapping
    execute l:rplugMapping

    let l:nlhsMapping = substitute(a:nmapcmd, 'noremap', 'map', '')  . ' ' . a:nlhs . ' ' . l:nplugname
    let l:vlhsMapping = substitute(a:vmapcmd, 'noremap', 'map', '')  . ' ' . a:vlhs . ' ' . l:vplugname
    execute l:nlhsMapping
    execute l:vlhsMapping

    return
echomsg '****' l:nplugMapping
echomsg '****' l:vplugMapping
echomsg '****' l:rplugMapping
echomsg '****' l:nlhsMapping
echomsg '****' l:vlhsMapping
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
