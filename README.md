REPEATABLE MAPPING
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

This plugin simplifies the application of the repeat.vim and visualrepeat.vim
repeat functionality to existing mappings. As with repeat.vim, all
embellishments are optional; if the corresponding plugin isn't available, the
call will be ignored and the original mappings persist unchanged (though
without any repeat functionality).

### RETROFIT MAPPING REPETITION
Some plugins provide out-of-the-box support for repeat.vim, many do not.
Some mappings have been developed in an ad-hoc fashion, e.g. as custom
filetype-specific workflow shortcuts, and therefore do not have the
canonical remapping layer of &lt;Plug&gt; mappings (which repeat.vim requires).

This plugin allows to retrofit repeatability to mappings from plugins that
do not directly use repeat.vim. It also offers a succinct way for custom
mappings to acquire repeatability, and spares them the definition of
&lt;Plug&gt;-mappings and adding the repeat#set() boilerplate code themselves.

### VISUAL MODE REPETITION
repeat.vim only supports normal mode repetition, as this is the only
repetition that is built into Vim. However, one can define repetition in
visual mode:

    xnoremap . :normal .<CR>

or with pass-through of [count]:

    xnoremap . :execute 'normal' (v:count ? v:count : '') . '.'<CR>

(Or better a more fancy version that only applies the repeat command over
entire lines in linewise visual mode, keeps the current cursor position in
characterwise visual mode, and does nothing (sensible) in blockwise visual
mode. The visualrepeat.vim plugin provides this.)

The &lt;Plug&gt;(ReenterVisualMode) mapping allows to apply repeat.vim repetition to
visual mode commands; just prepend it in the call to repeat#set():

    vnoremap <silent> <Plug>MyMapping ...:silent! call repeat#set("\<Plug>(ReenterVisualMode)\<Plug>MyMapping")<CR>

If a previously used visual mode mapping is repeated from an active visual
selection, that selection is the affected area for the repetition. The
recorded repeat count is passed to the mapping.

If repetition is invoked in normal mode, the repetition works on a new
selection, depending on the last visual mode:
- For linewise selections, the repetition selects the current line.
- For characterwise selections, a new selection starting at the cursor
  position, with the same size as the last visual selection is used. 1v
A [count] is passed to the mapping and overrides the recorded one.

If a non-visual mode mapping is repeated from an active visual selection, it
won't (can't) apply to the visual selection, but to whatever that mapping
typically applies. So, you can only repeat previous visual mode mappings on
a visual selection! The only way around this is to cross-link both mapping
types, and to use a more intelligent version of the repeat definition in
visual mode. This is described next:

### CROSS-REPEAT
Through the visualrepeat.vim plugin, it is possible to make normal mode and
visual mode mappings repeat each other, with the normal mode mapping repeated
over the visual selection, and the visual mode mapping repeated over a new
selection, such as:
- For previous linewise selections, the repetition applies to the same amount
  of lines, unless a different [count] is given. In that case, it selects
  [count] lines starting at the cursor position.
- Else, a new selection starting at the cursor position, with the same size as
  the last visual selection (times [count], if given and different) is used.
  1v
The mapping itself is always repeated with the recorded [count], not a new
given one. For cross-repeat of a visual mode mapping in normal mode, a new
different [count] only affects the range it applies to!

For cross-repeat, use the repeatableMapping#makeCrossRepeatable() function,
for single normal mode and visual mode mappings, and
repeatableMapping#makeMultipleCrossRepeatable() for multiple normal mode and
a single visual mode mapping.
For existing &lt;Plug&gt;-mappings, there's the
repeatableMapping#makeMultiplePlugMappingCrossRepeatable() function.

If the repeat needs to go to a different &lt;Plug&gt;-mapping (for example when you
have a mapping that queries the user, and you want to avoid the query on
repeat through a non-interactive mapping variant that recalls the saved
original query's value), use the
repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable()
function. With this variant of repeatableMapping#makeCrossRepeatable(), you
can specify separate repeat &lt;Plug&gt;-mappings:

    silent! call repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable(
    \   'nnoremap', '<Plug>(FooRange)',           '<Plug>(FooRangeRepeat)',
    \   'xnoremap', '<Plug>(FooSelection)',       '<Plug>(FooSelectionRepeat)'
    \)
    silent! call repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable(
    \   'nnoremap', '<Plug>(FooRangeRepeat)',     '<Plug>(FooRangeRepeat)',
    \   'xnoremap', '<Plug>(FooSelectionRepeat)', '<Plug>(FooSelectionRepeat)'
    \)

### RELATED WORKS

- Repeatable.vim (https://github.com/kreskij/Repeatable.vim) adds repeat.vim
  support simply by prepending its :Repeatable command to the :map command.

USAGE
------------------------------------------------------------------------------

### RETROFIT MAPPING REPETITION
    First define your mapping in the usual way:
        nnoremap <silent> <Leader>v :version<CR>
    Then make the mapping repeatable; this will redefine the original mapping
    and insert the call to repeat#set() at the end.
        silent! call repeatableMapping#makeRepeatable('nnoremap', '<Leader>v', 'ShowVersion')

    The processing requires the following information:
    - The original mapping command (for the map-mode, whether :noremap or not,
      any optional map-arguments like "<buffer>"; "<silent>" is added
      automatically to avoid showing the repeat invocation).
    - The mapping's {lhs} (i.e. keys that invoke the mapping).
    - A unique name for the intermediate <Plug>-mapping that needs to be created
      so that repeat.vim can invoke it.
    - Optional: The default count that will be prefixed to the mapping if no
      explicit numeric argument was given; i.e. the second optional argument of
      repeat#set(). If your mapping doesn't accept a numeric argument and you
      never want to receive one, pass a value of -1.
    Note that the wrapped Ex command in the mapping must support command
    sequencing with | (i.e. custom commands must be defined with :command-bar),
    as the repeat insertion will be appended with <Bar>. If that is not the case,
    wrap the command in :execute.

    If you already have a <Plug> mapping:
        vnoremap <silent> <Plug>ShowVersion :<C-U>version<CR>
        vmap <Leader>v <Plug>ShowVersion
    You can redefine the <Plug> mapping directly, and just have the call to
    repeat#set() appended:
        silent! call repeatableMapping#makePlugMappingRepeatable('vnoremap', '<Plug>ShowVersion')
    This is especially useful to retrofit existing visual mode mappings with the
    ability to be repeatable, in conjunction with the visual mode repetition
    described above.

### VISUAL MODE REPETITION
    First define your normal and visual mode mappings:
        nnoremap <buffer> <LocalLeader>qq :s/^/> /<CR>
        vnoremap <buffer> <LocalLeader>q  :s/^/> /<CR>

    You could now make both mappings repeatable via two separate calls to
    repeatableMapping#makeRepeatable(), as described in the above section, but
    with that, the mappings won't repeat each other. Therefore, it is recommended
    to use repeatableMapping#makeCrossRepeatable(), so that the normal mode
    mapping can be repeated over a visual selection and vice versa:
        silent! call repeatableMapping#makeCrossRepeatable(
        \   'nnoremap <buffer>', '<LocalLeader>qq', 'QuoteLine',
        \   'vnoremap <buffer>', '<LocalLeader>q',  'QuoteSelection'
        \)

    Again, if you already have <Plug> mappings (and need them for a configurable
    plugin), you can use the alternative function:
        silent! call repeatableMapping#makePlugMappingCrossRepeatable(
        \   'nnoremap <buffer>', '<Plug>QuoteLine',
        \   'vnoremap <buffer>', '<Plug>QuoteSelection'
        \)
    Note that you need to do this _after_ any
        if ! hasmapto('<Plug>QuoteLine', 'n') ...
    default mapping tests; because the <Plug>-mapping is contained in the
    retrofitted mapping, the test would otherwise always be false, and the default
    mappings would be missing!

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-repeatableMapping
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim repeatableMapping*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- repeat.vim ([vimscript #2136](http://www.vim.org/scripts/script.php?script_id=2136)) plugin (optional, but without it this plugin
  doesn't provide any functionality).
- visualrepeat.vim ([vimscript #3848](http://www.vim.org/scripts/script.php?script_id=3848) plugin) (version 2.00 or higher; optional,
  but recommended for cross-repeat functionality).

LIMITATIONS
------------------------------------------------------------------------------

- When your mapping uses :normal commands or a sequence of Ex commands
  separated by &lt;CR&gt;:, the original [count] is lost and won't be used in
  repeats. If you need the count, you cannot use this plugin. Instead,
  preserve the count yourself at the beginning of the mapping, and implement
  the calls to repeat#set() yourself.

### CONTRIBUTING

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-repeatableMapping/issues or email (address
below).

HISTORY
------------------------------------------------------------------------------

##### 2.20    03-Apr-2020
- ENH: All functions now support a second optional a:isRepeatRegister argument
  (to skip specifying a a:defaultCount, pass an empty String as the first
  optional argument) that if set invokes repeat#setreg() before the original
  {rhs} and also tweaks the repeat mappings that recreate a visual selection
  (which clobber count and also register) to save and restore the repeated
  register for the repeat as well.

##### 2.11    25-Jul-2019
- Documentation: Mention that a &lt;silent&gt; map-argument does not need to be
  passed; I was confused about this myself.
- FIX: The ingo-library may not be loaded yet (as repeatable mappings are
  usually defined early in plugin scripts); try loading it before testing for
  its existence.
- Escaping (duplicated from ingo#compat#maparg()) didn't consider &lt;; in fact,
  it needs to escape stand-alone &lt; and escaped \\&lt;, but not proper key
  notations like &lt;C-CR&gt;.

##### 2.10    08-Mar-2015
- ENH: Allow to pass Funcref as a:defaultCount; the value will then be
  determined via a dynamic lookup. This is necessary for mappings that clobber
  v:count (e.g. due to use of :normal). They can now save the original count
  and pass it on to the repeat part via the Funcref, which is more elegant
  than a global variable.

##### 2.01    19-Nov-2014
- BUG: Typo in repeatableMapping#makePlugMappingCrossRepeatable() causes
  "E116: Invalid arguments for function call", which unfortunately usually is
  suppressed by the :silent! invocation.

##### 2.00    22-Nov-2013
- ENH: Enable cross-repeat for existing &lt;Plug&gt;-mappings (as provided by
  plugins), too. The new functions parallel to the existing ones are
  repeatableMapping#makePlugMappingCrossRepeatable(),
  repeatableMapping#makeMultipleCrossRepeatable().
- CHG: In cross-repeat, select [count] lines / times the original selection
  when [count] is given and different from the repeat count, and pass the
  original count into the repeated mapping.
- Rework &lt;Plug&gt;(ReenterVisualMode) for when there's no cross-repeat to handle
  [count] in a way similar to the changed cross-repeat.
- FIX: Optional a:defaultCount argument for repeat#set() is only used when
  visualrepeat.vim is not installed.
- FIX: Also need to drop off &lt;script&gt; from the a:mapCmd to turn it into an
  effective &lt;Plug&gt; mapping command.
- ENH: Insert the repeat calls after the last &lt;CR&gt;, even if it is not at the
  end of the original mapping. This allows preserving the count for those
  mappings, too.
- Minor: Consider actual visual map mode of a:visualMapCmd (one of 'v', 'x',
  or 's').
- Move the functions for cross-repeating a visual mapping in normal mode
  through visualrepeat.vim to visualrepeat/reapply.vim to allow re-use in
  other plugins without forcing a dependency to this plugin. Since this
  functionality is only ever invoked through an installed visualrepeat.vim, it
  truly belongs there, not here.
- Make the &lt;Plug&gt; prefix optional for repeatableMapping#makeRepeatable(),
  repeatableMapping#makeCrossRepeatable(),
  repeatableMapping#makeMultipleCrossRepeatable().
- ENH: Also allow cross-repeat for existing &lt;Plug&gt;-mappings that need to call
  a different repeat &lt;Plug&gt;-mapping via
  repeatableMapping#makePlugMappingWithDifferentRepeatCrossRepeatable().

##### 1.00    13-Dec-2011 (unreleased)
- First version.

##### 0.01    24-Sep-2008
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2008-2020 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
