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
"   1.00.008	13-Dec-2011	Consistency: Renamed variables. 
"				Add documentation for public functions. 
"				Rename <Plug>ReenterVisualMode. 
"	007	12-Dec-2011	Add
"				repeatableMapping#makeMultipleCrossRepeatable()
"				for the special case of multiple normal mode
"				mappings in ingotextobjects.vim. 
"				FIX: Correct fallback for
"				repeatableMapping#makeCrossRepeatable() and pass
"				optional arguments, too. 
"				FIX: Must :runtime visualrepeat plugin before
"				the existence check when repeatableMappings are
"				defined in plugins that are sourced before the
"				visualrepeat plugin. 
"	006	08-Dec-2011	Rename variables; just a single-letter
"				difference isn't enough. 
"				Implement fallback for
"				repeatableMapping#makeCrossRepeatable when
"				visualrepeat.vim isn't available. 
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
nnoremap <silent> <expr> <Plug>(ReenterVisualMode) <SID>ReenterVisualMode()

function! s:GetRhsAndCmdJoiner( lhs, mapMode )
    let l:rhs = maparg(a:lhs, a:mapMode)
    let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')	" '|' must be escaped, or the map command will end prematurely.  
    if l:rhs =~? ':.*<CR>$'
	let l:rhs = substitute(l:rhs, '\c<CR>$', '', '')
	let l:cmdJoiner = '<Bar>'
    else
	let l:cmdJoiner = ':'
    endif

    return [l:rhs, l:cmdJoiner]
endfunction

function! s:MakePlugMappingWithRepeat( mapCmd, lhs, plugName, ... )
    let l:mapMode = (a:mapCmd =~# '^\w\%(nore\)\?map' ? a:mapCmd[0] : '')

    let [l:rhs, l:cmdJoiner] = s:GetRhsAndCmdJoiner(a:lhs, l:mapMode)

    let l:plugMapping = a:mapCmd . ' <silent> ' . a:plugName . ' ' . l:rhs . 
    \	l:cmdJoiner . 'silent! call repeat#set("' . 
    \	(l:mapMode ==# 'v' ? '\<Plug>(ReenterVisualMode)' : '') . 
    \	'\' . a:plugName .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<CR>'
"****D echomsg l:plugMapping
    execute l:plugMapping
endfunction

function! repeatableMapping#makeRepeatable( mapCmd, lhs, mapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the mapping of a:lhs repeatable through a new a:mapName <Plug>-mapping. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   Defines new <Plug>-mapping. 
"   Modifies the original a:lhs mapping to use the <Plug>-mapping. 
"* INPUTS:
"   a:mapCmd	The original mapping command and optional map-arguments used
"		(like "<buffer>"). 
"   a:lhs	The mapping's lhs (i.e. keys that invoke the mapping). 
"   a:mapName	Name of the intermediate <Plug>-mapping that is created. 
"* RETURN VALUES: 
"   None. 
"******************************************************************************
    let l:plugName = '<Plug>' . a:mapName
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:lhs, l:plugName] + a:000)

    let l:lhsMapping = substitute(a:mapCmd, 'noremap', 'map', '')  . ' ' . a:lhs . ' ' . l:plugName
"****D echomsg l:lhsMapping
    execute l:lhsMapping
endfunction

function! repeatableMapping#makePlugMappingRepeatable( mapCmd, mapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the <Plug>-mapping a:mapName repeatable. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   Redefines the a:mapName <Plug>-mapping. 
"* INPUTS:
"   a:mapCmd	The original mapping command and optional map-arguments used
"		(like "<buffer>"). 
"   a:mapName	Name of the <Plug>-mapping to be made repeatable. 
"* RETURN VALUES: 
"   None. 
"******************************************************************************
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:mapName, a:mapName] + a:000)
endfunction

function! s:RepeatSection( normalRepeatPlug, visualRepeatPlug )
    return
    \	'silent! call repeat#set("' .
    \	'\' . a:normalRepeatPlug .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<Bar>silent! call visualrepeat#set("' .
    \	'\' . a:visualRepeatPlug .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<CR>'

endfunction
function! repeatableMapping#makeCrossRepeatable( normalMapCmd, normalLhs, normalMapName, visualMapCmd, visualLhs, visualMapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the passed normal and visual mode mappings repeatable, both in the same
"   mode and across the different modes. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   Defines new <Plug>-mappings for normal and visual mode. 
"   Modifies the original a:normalLhs and a:visualLhs mappings to use the
"   corresponding <Plug>-mappings. 
"* INPUTS:
"   a:normalMapCmd	The original normal mode mapping command and optional
"			map-arguments used (like "<buffer>"). 
"   a:normalLhs		The mapping's lhs (i.e. keys that invoke the mapping). 
"   a:normalMapName	Name of the intermediate <Plug>-mapping that is created. 
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word". 
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"). 
"   a:visualLhs		The mapping's lhs (i.e. keys that invoke the mapping). 
"   a:visualMapName	Name of the intermediate <Plug>-mapping that is created. 
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection". 
"* RETURN VALUES: 
"   None. 
"******************************************************************************
    if a:normalMapName ==# a:visualMapName | throw 'ASSERT: normalMapName and visualMapName must be different' | endif

    if ! exists('g:loaded_visualrepeat')
	runtime plugin/visualrepeat.vim
    endif
    if ! exists('g:loaded_visualrepeat') || ! g:loaded_visualrepeat
	" The visualrepeat plugin isn't installed. Fall back to mapping them
	" separately, with just the <Plug>(ReenterVisualMode) feature for the
	" visual mode mapping. 
	if ! empty(a:normalMapCmd) | call call('repeatableMapping#makeRepeatable', [a:normalMapCmd, a:normalLhs, a:normalMapName] + a:000) | endif
	if ! empty(a:visualMapCmd) | call call('repeatableMapping#makeRepeatable', [a:visualMapCmd, a:visualLhs, a:visualMapName] + a:000) | endif
	return
    endif

    let l:normalPlugName = '<Plug>' . a:normalMapName
    let l:visualPlugName = '<Plug>' . a:visualMapName

    let [l:normalRhs, l:normalCmdJoiner] = s:GetRhsAndCmdJoiner(a:normalLhs, 'n')
    let [l:visualRhs, l:visualCmdJoiner] = s:GetRhsAndCmdJoiner(a:visualLhs, 'v')

    let l:normalPlugMapping = a:normalMapCmd . ' <silent> ' . l:normalPlugName . ' ' .
    \	l:normalRhs .
    \	l:normalCmdJoiner .
    \	s:RepeatSection(l:normalPlugName, l:visualPlugName)

    let l:visualPlugMapping = a:visualMapCmd . ' <silent> ' . l:visualPlugName . ' ' .
    \	l:visualRhs .
    \	l:visualCmdJoiner .
    \	s:RepeatSection(l:visualPlugName, l:visualPlugName)

    let l:repeatPlugMapping = a:normalMapCmd . ' <silent> ' . l:visualPlugName . ' ' .
    \	":<C-u>execute 'normal!' v:count1 . 'v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')<CR>" .
    \	l:visualRhs .
    \	l:visualCmdJoiner .
    \	s:RepeatSection(l:visualPlugName, l:visualPlugName)

    if ! empty(a:normalMapCmd)
	execute l:normalPlugMapping
	execute l:repeatPlugMapping
    endif
    if ! empty(a:visualMapCmd)
	execute l:visualPlugMapping
    endif

    let l:normalLhsMapping = substitute(a:normalMapCmd, 'noremap', 'map', '')  . ' ' . a:normalLhs . ' ' . l:normalPlugName
    let l:visualLhsMapping = substitute(a:visualMapCmd, 'noremap', 'map', '')  . ' ' . a:visualLhs . ' ' . l:visualPlugName
    if ! empty(a:normalMapCmd) | execute l:normalLhsMapping | endif
    if ! empty(a:visualMapCmd) | execute l:visualLhsMapping | endif

    return
echomsg '****' l:normalPlugMapping
echomsg '****' l:visualPlugMapping
echomsg '****' l:repeatPlugMapping
echomsg '****' l:normalLhsMapping
echomsg '****' l:visualLhsMapping
endfunction

function! repeatableMapping#makeMultipleCrossRepeatable( normalDefs, visualMapCmd, visualLhs, visualMapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the passed list of normal mode mappings and the passed visual mode
"   mapping repeatable, both in the same mode and across the different modes. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   Defines new <Plug>-mappings for normal and visual mode. 
"   Modifies the original a:normalLhs and a:visualLhs mappings to use the
"   corresponding <Plug>-mappings. 
"* INPUTS:
"   a:normalDefs	List of normal mode mapping definitions, which are
"			tuples of [a:normalMapCmd, a:normalLhs, a:normalMapName]
"	a:normalMapCmd	The original normal mode mapping command and optional
"			map-arguments used (like "<buffer>"). 
"	a:normalLhs	The mapping's lhs (i.e. keys that invoke the mapping). 
"	a:normalMapName	Name of the intermediate <Plug>-mapping that is created. 
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word". 
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"). 
"   a:visualLhs		The mapping's lhs (i.e. keys that invoke the mapping). 
"   a:visualMapName	Name of the intermediate <Plug>-mapping that is created. 
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection". 
"* RETURN VALUES: 
"   None. 
"******************************************************************************
    for l:idx in range(len(a:normalDefs))
	" The visual mapping must only be overridden on the last iteration; all
	" repeat mappings must be defined using the original RHS of the visual
	" mapping. 
	let l:isLastNormalDef = (l:idx == len(a:normalDefs) - 1)

	call call('repeatableMapping#makeCrossRepeatable',
	\   a:normalDefs[l:idx] +
	\   [(l:isLastNormalDef ? a:visualMapCmd : ''), a:visualLhs, a:visualMapName] +
	\   a:000
	\)
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
