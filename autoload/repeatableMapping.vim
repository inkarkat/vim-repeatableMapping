" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim.
"
" DEPENDENCIES:
"   - repeat.vim (vimscript #2136) plugin (optional)
"   - visualrepeat.vim (vimscript #3848) plugin (optional)
"   - ingo-library.vim plugin (optional)
"
" Copyright: (C) 2008-2020 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
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

function! s:ReapplyVisualMode()
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
" s:ReapplyVisualMode(). Then put back the [count] via <SID>(ReapplyGivenCount)
" so that it applies to the repeated mapping. Note that without cross-repeat, a
" normal mode repeat of the visual mode mapping will work, but always on the
" current line / same-size selection with the original [count]. This is
" different from cross-repeat, where one can specify [count] lines / times the
" original selection, with the original repeat.
nnoremap <silent> <script> <Plug>(ReenterVisualMode)
\   :<C-u>execute 'normal! ' . <SID>ReapplyVisualMode()<CR><SID>(ReapplyGivenCount)


let s:register = '"'
function! s:CaptureRegister() abort
    let s:register = v:register
    return ''
endfunction
function! s:GetRegister() abort
    return s:register
endfunction
nnoremap <silent> <expr> <SID>(CaptureRegister) <SID>CaptureRegister()
vnoremap <silent> <expr> <SID>(CaptureRegister) <SID>CaptureRegister()
function! s:ReapplyRegister() abort
    return (s:register ==# '"' ? '' : '"' . s:register)
endfunction
vnoremap <silent> <expr> <SID>(ReapplyRegister) <SID>ReapplyRegister()
function! s:GetCaptureRegisterParameters( isCaptureRegister )
    return (a:isCaptureRegister ?
    \   ['<script> ', '<SID>(CaptureRegister)', 'call <SID>CaptureRegister()<Bar>', '<SID>(ReapplyRegister)'] :
    \   ['', '', '', '']
    \)
endfunction


silent! call ingo#compat#maparg('') " Try loading the ingo-library autoload script before testing for its existence.
function! s:GetRhsAndCmdJoiner( lhs, mapMode )
    if exists('*ingo#compat#maparg')    " Avoid hard dependency to ingo-library.
	let l:rhs = ingo#compat#maparg(a:lhs, a:mapMode)
    else
	let l:rhs = maparg(a:lhs, a:mapMode)
	" Duplicated from ingo#compat#maparg() to avoid dependency to
	" ingo-library.
	let l:rhs = substitute(l:rhs, '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\zs<\|<\%([^<]\+>\)\@!', '<lt>', 'g')    " Escape stand-alone < (when not part of a key-notation), or when escaped \<, but not proper key-notation like <C-CR>.
	let l:rhs = substitute(l:rhs, '|', '<Bar>', 'g')    " '|' must be escaped, or the map command will end prematurely.
    endif
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
    let l:isCaptureRegister = (a:0 >= 2 && a:2)
    let [l:captureRegisterModifier, l:captureRegisterMapping, l:captureRegisterExpr, l:captureRegisterReapplyMapping] = s:GetCaptureRegisterParameters(l:isCaptureRegister)
    let l:mapMode = (a:mapCmd =~# '^\w\%(nore\)\?map' ? a:mapCmd[0] : '')
    let l:repeatMapping = (l:mapMode =~# '^[vxs]$' ? l:captureRegisterMapping . '\<Plug>(ReenterVisualMode)' . l:captureRegisterReapplyMapping : '') . '\' . a:plugName

    let [l:rhsBefore, l:cmdJoiner, l:rhsAfter] = s:GetRhsAndCmdJoiner(a:lhs, l:mapMode)

    let l:plugMapping = a:mapCmd . ' <silent> ' . l:captureRegisterModifier . a:plugName . ' ' .
    \   l:captureRegisterMapping .
    \   l:rhsBefore .
    \	l:cmdJoiner .
    \   (l:isCaptureRegister ?
    \       'silent! call repeat#setreg("' . l:repeatMapping . '", <SID>GetRegister())<Bar>' :
    \       ''
    \   ) .
    \   'silent! call repeat#set("' .
    \	l:repeatMapping .
    \	'"' . (a:0 && a:1 isnot# '' ? ', ' . s:RenderCount(a:1) : '') .
    \	')<CR>' .
    \   l:rhsAfter
"****D unsilent echomsg l:plugMapping string(a:mapCmd) string(a:lhs) string(a:plugName)
    execute l:plugMapping
endfunction

function! s:PlugMapCmd( mapCmd )
    let l:plugMapCmd = a:mapCmd
    let l:plugMapCmd = substitute(l:plugMapCmd, '\Cnoremap', 'map', '')
    let l:plugMapCmd = substitute(l:plugMapCmd, '\C<script>', '', '')
    return l:plugMapCmd
endfunction
function! s:PlugMap( mapName )
    return (a:mapName =~# '^<Plug>' ? a:mapName : '<Plug>' . a:mapName)
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
"		(like "<buffer>"; but <silent> is added implicitly).
"   a:lhs	The mapping's lhs (i.e. keys that invoke the mapping).
"   a:mapName	Name of the intermediate <Plug>-mapping that is created. (The
"		<Plug> prefix is optional.)
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:plugName = s:PlugMap(a:mapName)
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:lhs, l:plugName] + a:000)

    let l:lhsMapping = s:PlugMapCmd(a:mapCmd)  . ' ' . a:lhs . ' ' . l:plugName
"****D unsilent echomsg l:lhsMapping
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
"		(like "<buffer>"; but <silent> is added implicitly).
"   a:mapName	Name of the <Plug>-mapping to be made repeatable.
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
"* RETURN VALUES:
"   None.
"******************************************************************************
    call call('s:MakePlugMappingWithRepeat', [a:mapCmd, a:mapName, a:mapName] + a:000)
endfunction

function! s:RepeatSection( normalRepeatPlug, visualRepeatPlug, ... )
    let l:isCaptureRegister = (a:0 >= 2 && a:2)
    return
    \   (l:isCaptureRegister ?
    \       'silent! call repeat#setreg("' . '\' . a:normalRepeatPlug . '", <SID>GetRegister())<Bar>' :
    \       ''
    \   ) .
    \	'silent! call repeat#set("' .
    \	'\' . a:normalRepeatPlug .
    \	'"' . (a:0 && a:1 isnot# '' ? ', ' . s:RenderCount(a:1) : '') .
    \	')<Bar>silent! call visualrepeat#set("' .
    \	'\' . a:visualRepeatPlug .
    \	'"' . (a:0 && a:1 isnot# '' ? ', ' . s:RenderCount(a:1) : '') .
    \	')<CR>'
endfunction
function! s:RenderCount( Count )
    return (type(a:Count) == type(function('tr')) ?
    \   printf('call(%s, [])', string(a:Count)):
    \   a:Count
    \)
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
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"   a:normalLhs		The mapping's lhs (i.e. keys that invoke the mapping).
"   a:normalMapName	Name of the intermediate <Plug>-mapping that is created.
"			(The <Plug> prefix is optional.)
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"			(The <Plug> prefix is optional.)
"   a:visualLhs		The mapping's lhs (i.e. keys that invoke the mapping).
"   a:visualMapName	Name of the intermediate <Plug>-mapping that is created.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
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

    let l:isCaptureRegister = (a:0 >= 2 && a:2)
    let [l:captureRegisterModifier, l:captureRegisterMapping, l:captureRegisterExpr, l:captureRegisterReapplyMapping] = s:GetCaptureRegisterParameters(l:isCaptureRegister)

    let l:normalPlugName = s:PlugMap(a:normalMapName)
    let l:visualPlugName = s:PlugMap(a:visualMapName)

    let [l:normalRhsBefore, l:normalCmdJoiner, l:normalRhsAfter] = s:GetRhsAndCmdJoiner(a:normalLhs, 'n')
    let [l:visualRhsBefore, l:visualCmdJoiner, l:visualRhsAfter] = s:GetRhsAndCmdJoiner(a:visualLhs, a:visualMapCmd[0])

    let l:normalPlugMapping = a:normalMapCmd . ' <silent> ' . l:captureRegisterModifier . l:normalPlugName . ' ' .
    \   l:captureRegisterMapping .
    \	l:normalRhsBefore .
    \	l:normalCmdJoiner .
    \	call('s:RepeatSection', [l:normalPlugName, l:visualPlugName] + a:000) .
    \   l:normalRhsAfter

    let l:visualPlugMapping = a:visualMapCmd . ' <silent> ' . l:captureRegisterModifier . l:visualPlugName . ' ' .
    \   l:captureRegisterMapping .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [l:visualPlugName, l:visualPlugName] + a:000) .
    \   l:visualRhsAfter

    let l:repeatPlugMapping = a:normalMapCmd . ' <silent> <script> ' . l:visualPlugName . ' ' .
    \	':<C-u>' . l:captureRegisterExpr .  "execute 'normal! ' . <SID>VisualMode()<CR>" .
    \   '<SID>(ReapplyRepeatCount)' .
    \   l:captureRegisterReapplyMapping .
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
unsilent echomsg '****' l:normalPlugMapping
unsilent echomsg '****' l:visualPlugMapping
unsilent echomsg '****' l:repeatPlugMapping
unsilent echomsg '****' l:normalLhsMapping
unsilent echomsg '****' l:visualLhsMapping
endfunction
function! repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable( normalMapCmd, normalMapName, normalRepeatMapName, visualMapCmd, visualMapName, visualRepeatMapName, ... )
"******************************************************************************
"* PURPOSE:
"   Make the passed normal and visual mode <Plug>-mappings repeatable via
"   separate repeat <Plug>-mappings, both in the same mode and across the
"   different modes.
"   Use for example when you have a mapping that queries the user, and you want
"   to avoid the query on repeat through a non-interactive mapping variant that
"   recalls the saved original query's value.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Redefines the original a:normalMapName and a:visualMapName mappings.
"* INPUTS:
"   a:normalMapCmd	    The original normal mode mapping command and
"			    optional map-arguments used (like "<buffer>"; but
"			    <silent> is added implicitly).
"   a:normalMapName	    Name of the <Plug>-mapping to be made repeatable.
"			    This must be different from the a:visualMapName;
"			    typically the normal mode name contains the scope,
"			    e.g. "Line" or "Word".
"   a:normalRepeatMapName   Name of the <Plug>-mapping that is invoked on
"			    repeat. Typically like a:normalMapName with appended
"			    "Repeat".
"   a:visualMapCmd	    The original visual mode mapping command and
"			    optional map-arguments used (like "<buffer>"; but
"			    <silent> is added implicitly).
"   a:visualMapName	    Name of the <Plug>-mapping to be made repeatable.
"			    This must be different from the a:normalMapName;
"			    typically the visual mode name contains "Selection".
"   a:visualRepeatMapName   Name of the <Plug>-mapping that is invoked on
"			    repeat. Typically like a:visualMapName with appended
"			    "repeat".
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
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
	if ! empty(a:normalMapCmd) | call call('repeatableMapping#makePlugMappingRepeatable', [a:normalMapCmd, a:normalRepeatMapName] + a:000) | endif
	if ! empty(a:visualMapCmd) | call call('repeatableMapping#makePlugMappingRepeatable', [a:visualMapCmd, a:visualRepeatMapName] + a:000) | endif
	return
    endif

    let l:isCaptureRegister = (a:0 >= 2 && a:2)
    let [l:captureRegisterModifier, l:captureRegisterMapping, l:captureRegisterExpr, l:captureRegisterReapplyMapping] = s:GetCaptureRegisterParameters(l:isCaptureRegister)

    let [l:normalRhsBefore, l:normalCmdJoiner, l:normalRhsAfter] = s:GetRhsAndCmdJoiner(a:normalMapName, 'n')
    let [l:visualRhsBefore, l:visualCmdJoiner, l:visualRhsAfter] = s:GetRhsAndCmdJoiner(a:visualMapName, a:visualMapCmd[0])

    let l:normalPlugMapping = a:normalMapCmd . ' <silent> ' . l:captureRegisterModifier . a:normalMapName . ' ' .
    \   l:captureRegisterMapping .
    \	l:normalRhsBefore .
    \	l:normalCmdJoiner .
    \	call('s:RepeatSection', [a:normalRepeatMapName, a:visualRepeatMapName] + a:000) .
    \   l:normalRhsAfter

    let l:visualPlugMapping = a:visualMapCmd . ' <silent> ' . l:captureRegisterModifier . a:visualMapName . ' ' .
    \   l:captureRegisterMapping .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [a:visualRepeatMapName, a:visualRepeatMapName] + a:000) .
    \   l:visualRhsAfter

    let l:repeatPlugMapping = a:normalMapCmd . ' <silent> <script> ' . a:visualRepeatMapName . ' ' .
    \	':<C-u>' . l:captureRegisterExpr . "execute 'normal! ' . <SID>VisualMode()<CR>" .
    \   '<SID>(ReapplyRepeatCount)' .
    \   l:captureRegisterReapplyMapping .
    \	l:visualRhsBefore .
    \	l:visualCmdJoiner .
    \	call('s:RepeatSection', [a:visualRepeatMapName, a:visualRepeatMapName] + a:000) .
    \   l:visualRhsAfter

    if ! empty(a:normalMapCmd)
	execute l:normalPlugMapping
	execute l:repeatPlugMapping
    endif
    if ! empty(a:visualMapCmd)
	execute l:visualPlugMapping
    endif

    return
unsilent echomsg '****' l:normalPlugMapping
unsilent echomsg '****' l:visualPlugMapping
unsilent echomsg '****' l:repeatPlugMapping
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
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"   a:normalMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"   a:visualMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
"* RETURN VALUES:
"   None.
"******************************************************************************
    call call('repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable', [a:normalMapCmd, a:normalMapName, a:normalMapName, a:visualMapCmd, a:visualMapName, a:visualMapName] + a:000)
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
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"	a:normalLhs	The mapping's lhs (i.e. keys that invoke the mapping).
"	a:normalMapName	Name of the intermediate <Plug>-mapping that is created.
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"			(The <Plug> prefix is optional.)
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"   a:visualLhs		The mapping's lhs (i.e. keys that invoke the mapping).
"   a:visualMapName	Name of the intermediate <Plug>-mapping that is created.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"			(The <Plug> prefix is optional.)
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
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
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"	a:normalMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:visualMapName;
"			typically the normal mode name contains the scope, e.g.
"			"Line" or "Word".
"   a:visualMapCmd	The original visual mode mapping command and optional
"			map-arguments used (like "<buffer>"; but <silent> is
"			added implicitly).
"   a:visualMapName	Name of the <Plug>-mapping to be made repeatable.
"			This must be different from the a:normalMapName;
"			typically the visual mode name contains "Selection".
"   a:defaultCount  Optional default count for repeat#set(). Pass '' (empty
"                   String) to omit. Can be a Funcref which is then invoked
"                   dynamically (without any arguments) to get the saved
"                   original v:count.
"   a:isRepeatRegister      Optional flag. If 1, the register is also stored and
"                           repeated (via repeat#setreg()).
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
