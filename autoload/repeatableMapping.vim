" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim.
"
" DEPENDENCIES:
"   - repeat.vim (vimscript #2136) autoload script (optional)
"   - visualrepeat.vim (vimscript #3848) autoload script (optional)
"   - visualrepeat/reapply.vim (vimscript #3848) autoload script (optional)
"
" Copyright: (C) 2008-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   2.00.011	18-Apr-2013	Also need to drop off <script> from the a:mapCmd
"				to turn it into an effective <Plug> mapping
"				command.
"				Rework <Plug>(ReenterVisualMode) for when
"				there's no cross-repeat to handle [count] in a
"				way similar to the changed cross-repeat.
"				Move the functions for cross-repeating a visual
"				mapping in normal mode through visualrepeat.vim
"				to visualrepeat/reapply.vim to allow re-use in
"				other plugins without forcing a dependency to
"				this plugin. Since this functionality is only
"				ever invoked through an installed
"				visualrepeat.vim, it truly belongs there, not
"				here.
"   2.00.010	17-Apr-2013	FIX: Optional a:defaultCount argument for
"				repeat#set() is only used when visualrepeat.vim
"				is not installed.
"				ENH: Insert the repeat calls after the last
"				<CR>, even if it is not at the end of the
"				original mapping. This allows preserving the
"				count for those mappings, too.
"				Consider actual visual map mode of
"				a:visualMapCmd (one of 'v', 'x', or 's').
"				CHG: In cross-repeat, select [count] lines /
"				times the original selection when [count] is
"				given and different from the repeat count, and
"				pass the original count into the repeated
"				mapping.
"   2.00.009	12-Apr-2013	ENH: Enable cross-repeat for existing
"				<Plug>-mappings (as provided by plugins), too.
"				The new functions parallel to the existing ones
"				are
"				repeatableMapping#makePlugMappingCrossRepeatable(),
"				repeatableMapping#makeMultipleCrossRepeatable().
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

" Support normal mode repeat of visual mode mapping (through only repeat.vim)
" when visualmode.vim isn't installed.
function! s:VisualMode()
    let l:keys = '1v'
    silent! let l:keys = visualrepeat#reapply#VisualMode(1)
    return l:keys
endfunction
vnoremap <silent> <expr> <SID>(ReapplyRepeatCount) visualrepeat#reapply#RepeatCount()

function! repeatableMapping#ReapplyVisualMode()
    let s:count = v:count
    if visualmode() ==# 'V'
	" If the command to be repeated was in linewise visual mode, the repeat
	" command is invoked for each individual line. Thus, we only need to
	" select the current line.
	return 'V'
    elseif getpos('.') == getpos("'<") || getpos('.') == getpos("'>")
	return 'gv'
    else
	return '1v' . (&selection ==# 'exclusive' ? ' ' : '')
    endif
endfunction
function! s:ReapplyGivenCount()
    return (s:count ? s:count : '')
endfunction
vnoremap <silent> <expr> <SID>(ReapplyGivenCount) <SID>ReapplyGivenCount()
" This gets triggered when repeating visual mode mappings that do not have
" defined a cross-repeatable normal mode mapping. Instead, through something
" like a simple :xmap . or the visualrepeat.vim plugin, the original visual mode
" mapping is re-applied, using this <Plug>(ReenterVisualMode) as a bridge from
" normal-mode back to visual mode.
" Use :normal first to swallow the passed [count], so that it doesn't affect the
" V / gv / 1v commands that are returned by
" repeatableMapping#ReapplyVisualMode(). Then put back the [count] via
" <SID>(ReapplyGivenCount) so that it applies to the repeated mapping.
" Note that without cross-repeat, a normal mode repeat of the visual mode
" mapping will work, but always on the current line / same-size selection with
" the original [count]. This is different from cross-repeat, where one can
" specify [count] lines / times the original selection, with the original
" repeat.
nnoremap <silent> <script> <Plug>(ReenterVisualMode)
\   :<C-u>execute 'normal!' repeatableMapping#ReapplyVisualMode()<CR><SID>(ReapplyGivenCount)



function! s:GetRhsAndCmdJoiner( lhs, mapMode )
    let l:rhs = maparg(a:lhs, a:mapMode)
    let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')	" '|' must be escaped, or the map command will end prematurely.
    if l:rhs =~? ':.*<CR>'
	let [l:rhsBefore, l:rhsAfter] = matchlist(l:rhs, '^\(.*\)\c<CR>\(.*\)$')[1:2]
	let l:cmdJoiner = '<Bar>'
    else
	let l:rhsBefore = l:rhs
	let l:cmdJoiner = ':'
	let l:rhsAfter = ''
    endif

    return [l:rhsBefore, l:cmdJoiner, l:rhsAfter]
endfunction

function! s:MakePlugMappingWithRepeat( mapCmd, lhs, plugName, ... )
    let l:mapMode = (a:mapCmd =~# '^\w\%(nore\)\?map' ? a:mapCmd[0] : '')

    let [l:rhsBefore, l:cmdJoiner, l:rhsAfter] = s:GetRhsAndCmdJoiner(a:lhs, l:mapMode)

    let l:plugMapping = a:mapCmd . ' <silent> ' . a:plugName . ' ' . l:rhsBefore .
    \	l:cmdJoiner . 'silent! call repeat#set("' .
    \	(l:mapMode =~# '^[vxs]$' ? '\<Plug>(ReenterVisualMode)' : '') .
    \	'\' . a:plugName .
    \	'"' . (a:0 ? ', ' . a:1 : '') .
    \	')<CR>' .
    \   l:rhsAfter
"****D echomsg l:plugMapping
    execute l:plugMapping
endfunction

function! s:PlugMapCmd( mapCmd )
    let l:plugMapCmd = a:mapCmd
    let l:plugMapCmd = substitute(l:plugMapCmd, 'noremap', 'map', '')
    let l:plugMapCmd = substitute(l:plugMapCmd, '<script>', '', '')
    return l:plugMapCmd
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
"   a:defaultCount  Optional default count for repeat#set().
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:plugName = '<Plug>' . a:mapName
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:lhs, l:plugName] + a:000)

    let l:lhsMapping = s:PlugMapCmd(a:mapCmd)  . ' ' . a:lhs . ' ' . l:plugName
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
"   a:defaultCount  Optional default count for repeat#set().
"* RETURN VALUES:
"   None.
"******************************************************************************
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:mapName, a:mapName] + a:000)
endfunction

function! s:RepeatSection( normalRepeatPlug, visualRepeatPlug, ... )
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
"   a:defaultCount  Optional default count for repeat#set().
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

    let [l:normalRhsBefore, l:normalCmdJoiner, l:normalRhsAfter] = s:GetRhsAndCmdJoiner(a:normalLhs, 'n')
    let [l:visualRhsBefore, l:visualCmdJoiner, l:visualRhsAfter] = s:GetRhsAndCmdJoiner(a:visualLhs, a:visualMapCmd[0])

    let l:normalPlugMapping = a:normalMapCmd . ' <silent> ' . l:normalPlugName . ' ' .
    \	l:normalRhsBefore .
    \	l:normalCmdJoiner .
    \	call('s:RepeatSection', [l:normalPlugName, l:visualPlugName] + a:000) .
    \   l:normalRhsAfter

    let l:visualPlugMapping = a:visualMapCmd . ' <silent> ' . l:visualPlugName . ' ' .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [l:visualPlugName, l:visualPlugName] + a:000) .
    \   l:visualRhsAfter

    let l:repeatPlugMapping = a:normalMapCmd . ' <silent> <script> ' . l:visualPlugName . ' ' .
    \	":<C-u>execute 'normal!' <SID>VisualMode()<CR>" .
    \   '<SID>(ReapplyRepeatCount)' .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [l:visualPlugName, l:visualPlugName] + a:000) .
    \   l:visualRhsAfter

    if ! empty(a:normalMapCmd)
	execute l:normalPlugMapping
	execute l:repeatPlugMapping
    endif
    if ! empty(a:visualMapCmd)
	execute l:visualPlugMapping
    endif

    let l:normalLhsMapping = s:PlugMapCmd(a:normalMapCmd) . ' ' . a:normalLhs . ' ' . l:normalPlugName
    let l:visualLhsMapping = s:PlugMapCmd(a:visualMapCmd) . ' ' . a:visualLhs . ' ' . l:visualPlugName
    if ! empty(a:normalMapCmd) | execute l:normalLhsMapping | endif
    if ! empty(a:visualMapCmd) | execute l:visualLhsMapping | endif

    return
echomsg '****' l:normalPlugMapping
echomsg '****' l:visualPlugMapping
echomsg '****' l:repeatPlugMapping
echomsg '****' l:normalLhsMapping
echomsg '****' l:visualLhsMapping
endfunction
function! repeatableMapping#makePlugMappingCrossRepeatable( normalMapCmd, normalMapName, visualMapCmd, visualMapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the passed normal and visual mode <Plug>-mappings repeatable, both in
"   the same mode and across the different modes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Redefines the original a:normalMapName and a:visualMapName mappings.
"* INPUTS:
"   a:normalMapCmd	The original normal mode mapping command and optional
"			map-arguments used (like "<buffer>").
"   a:normalMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>").
"   a:visualMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"   a:defaultCount  Optional default count for repeat#set().
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
	if ! empty(a:normalMapCmd) | call call('repeatableMapping#makePlugMappingRepeatable', [a:normalMapCmd, a:normalMapName] + a:000) | endif
	if ! empty(a:visualMapCmd) | call call('repeatableMapping#makePlugMappingRepeatable', [a:visualMapCmd, a:visualMapName] + a:000) | endif
	return
    endif

    let [l:normalRhsBefore, l:normalCmdJoiner, l:normalRhsAfter] = s:GetRhsAndCmdJoiner(a:normalMapName, 'n')
    let [l:visualRhsBefore, l:visualCmdJoiner, l:visualRhsAfter] = s:GetRhsAndCmdJoiner(a:visualMapName, a:visualMapCmd[0])

    let l:normalPlugMapping = a:normalMapCmd . ' <silent> ' . a:normalMapName . ' ' .
    \	l:normalRhsBefore .
    \	l:normalCmdJoiner .
    \	call('s:RepeatSection', [a:normalMapName, a:visualMapName] + a:000) .
    \   l:normalRhsAfter

    let l:visualPlugMapping = a:visualMapCmd . ' <silent> ' . a:visualMapName . ' ' .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [a:visualMapName, a:visualMapName] + a:000) .
    \   l:visualRhsAfter

    let l:repeatPlugMapping = a:normalMapCmd . ' <silent> <script> ' . a:visualMapName . ' ' .
    \	":<C-u>execute 'normal!' <SID>VisualMode()<CR>" .
    \   '<SID>(ReapplyRepeatCount)' .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [a:visualMapName, a:visualMapName] + a:000) .
    \   l:visualRhsAfter

    if ! empty(a:normalMapCmd)
	execute l:normalPlugMapping
	execute l:repeatPlugMapping
    endif
    if ! empty(a:visualMapCmd)
	execute l:visualPlugMapping
    endif

    return
echomsg '****' l:normalPlugMapping
echomsg '****' l:visualPlugMapping
echomsg '****' l:repeatPlugMapping
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
"   a:defaultCount  Optional default count for repeat#set().
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
function! repeatableMapping#makeMultiplePlugMappingCrossRepeatable( normalDefs, visualMapCmd, visualMapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the passed list of normal mode <Plug>-mappings and the passed visual
"   mode <Plug>-mapping repeatable, both in the same mode and across the
"   different modes.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Redefines the original <Plug>-mappings for normal and visual mode.
"* INPUTS:
"   a:normalDefs	List of normal mode mapping definitions, which are
"			tuples of [a:normalMapCmd, a:normalMapName]
"	a:normalMapCmd	The original normal mode mapping command and optional
"			map-arguments used (like "<buffer>").
"	a:normalMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>").
"   a:visualMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"   a:defaultCount  Optional default count for repeat#set().
"* RETURN VALUES:
"   None.
"******************************************************************************
    for l:idx in range(len(a:normalDefs))
	" The visual mapping must only be overridden on the last iteration; all
	" repeat mappings must be defined using the original RHS of the visual
	" mapping.
	let l:isLastNormalDef = (l:idx == len(a:normalDefs) - 1)

	call call('repeatableMapping#makePlugMappingCrossRepeatable',
	\   a:normalDefs[l:idx] +
	\   [(l:isLastNormalDef ? a:visualMapCmd : ''), a:visualMapName] +
	\   a:000
	\)
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
