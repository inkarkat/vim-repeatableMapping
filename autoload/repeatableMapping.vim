" repeatableMapping.vim: Set up mappings that can be repeated via repeat.vim. 
"
" DESCRIPTION:
"   RETROFIT MAPPING REPETITION: 
"   Some plugins provide out-of-the-box support for repeat.vim, many do not.
"   Some mappings have been developed in an ad-hoc fashion, e.g. as custom
"   filetype-specific workflow shortcuts, and therefore do not have the
"   canonical remapping layer of <Plug> mappings (which repeat.vim requires). 
"
"   This plugin allows to retrofit repeatability to mappings from plugins that
"   do not directly use repeat.vim. It also offers a succinct way for custom
"   mappings to acquire repeatability, and spares them the definition of
"   <Plug>-mappings and adding the repeat#set() boilerplate code themselves. 
"
"   VISUAL MODE REPETITION: 
"   repeat.vim only supports normal mode repetition, as this is the only
"   repetition that is built into Vim. However, one can define repetition in
"   visual mode:
"	xnoremap . :normal .<CR>
"   (Or better a more fancy version that only applies the repeat command over
"   entire lines in linewise visual mode, keeps the current cursor position in
"   characterwise visual mode, and does nothing (sensible) in blockwise visual
"   mode.) 
"
"   The <Plug>ReenterVisualMode mapping allows to apply repeat.vim repetition to
"   visual mode commands; just prepend it in the call to repeat#set():
"	vnoremap <silent> <Plug>MyMapping ...:silent! call repeat#set("\<Plug>ReenterVisualMode\<Plug>MyMapping")<CR>
"
"   If a visual mode mapping is repeated from an active visual selection, that
"   selection is the affected area for the repetition. If repetition is invoked
"   in normal mode, the repetition works on a new selection starting at the
"   cursor position, with the same size as the last visual selection (times
"   [count]). 
"   If a non-visual mode mapping is repeated from an active visual selection, it
"   won't (can't) apply to the visual selection, but to whatever that mapping
"   typically applies. So, you can only repeat previous visual mode mappings on
"   a visual selection! The only way around this is to cross-link both mapping
"   types, and to use an even more intelligent version of the repeat definition
"   in visual mode. 
"
"   Through visualrepeat.vim, it is possible to make normal mode and visual mode
"   mappings repeat each other, with the normal mode mapping through the visual
"   mode mapping repeated over the visual selection, and the visual mode mapping
"   repeated over a new selection starting at the cursor position, with the same
"   size as the last visual selection (times [count]). 
"   For this, use the repeatableMapping#makeCrossRepeatable() function. 

" USAGE:
"   First define your mapping in the usual way:
"	nnoremap <silent> <Leader>v :version<CR>
"   Then make the mapping repeatable; this will redefine the original mapping
"   and insert the call to repeat#set() at the end. 
"	silent! call repeatableMapping#makeRepeatable('nnoremap', '<Leader>v', 'Test2')
"   The processing requires the following information:
"   - The original mapping command (for the map-mode, whether "noremap" or not,
"     any optional map-arguments like "<buffer>"; "<silent>" is added
"     automatically to avoid showing the repeat invocation). 
"   - The mapping's lhs (i.e. keys that invoke the mapping). 
"   - A unique name for the intermediate <Plug> mapping that needs to be created
"     so that repeat.vim can invoke it. 
"   - Optional: The default count that will be prefixed to the mapping if no
"     explicit numeric argument was given; i.e. the second optional argument of
"     repeat#set(). If your mapping doesn't accept a numeric argument and you
"     never want to receive one, pass a value of -1.
"
"   If you already have a <Plug> mapping: 
"	vnoremap <silent> <Plug>ShowVersion :<C-U>version<CR>
"	vmap <Leader>v <Plug>ShowVersion
"   You can redefine the <Plug> mapping directly, and just have the call to
"   repeat#set() appended: 
"	silent! call repeatableMapping#makeRepeatable('vnoremap', '<Plug>ShowVersion')
"   This is especially useful to retrofit existing visual mode mappings with the
"   ability to be repeatable, in conjunction with the visual mode repetition
"   described above. 
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
