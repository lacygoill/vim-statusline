if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

" TODO: Set the status line in various special type of files.{{{
"
" `fex_tree`, `qf`, `undotree`...
"
" In `fex_tree`,  we've installed an autocmd,  but it will probably  not work in
" Nvim (read the rest of the comment to understand why).
"
" In  the   other  ones,  we   used  `User   MyFlags`  autocmds  in   the  past,
" but  we've  commented  them,  because  we've  changed  the  implementation  of
" `statusline#hoist()` (it doesn't support filetypes anymore).
"
" ---
"
" The status line in a non-focused qf window *was* noisy (I've fixed it).
" Are there other special types of files for which the same issue applies.
"}}}
" TODO: Review how you set `'stl'` in special types of files (dirvish, fex, websearch).{{{
"
" Make sure it's not too noisy when unfocused.
" Also, try to consolidate similar settings in a single autocmd in the same file.
" That is, if you notice that for most special types of files, you want/need the
" same status line, write a single autocmd to set all of them.
" It  would create  an easy  way  to add/remove  an `'stl'`  setting for  future
" special types of files.
"}}}
" TODO: Document which refactoring we will need to perform once 8.1.1372 has been ported to Nvim.{{{
"
" Search for `stl` everywhere.
" What will become useless?
" What could be simplified?
"
" Document everything here, so  that the day the patch is  ported, we can easily
" refactor our scripts.
"}}}
" TODO: Read the following links to improve the statusline.{{{

" Blog post talking about status line customization:
" http://www.blaenkdenum.com/posts/a-simpler-vim-statusline

" Vim Powerline-like status line without the need of any plugin:
" https://gist.github.com/ericbn/f2956cd9ec7d6bff8940c2087247b132
"}}}

" Options {{{1

" always show the status line and the tab line
set ls=2 stal=2

" `vim-flagship` recommends to remove the `e` flag from 'guioptions', because it:
" > disables the GUI tab line in favor of the plain text version
set guioptions-=e

set tabline=%!statusline#tabline()

" TODO: Once `8.1.1372` has been ported to Nvim, remove all the `if !has('nvim')` guards,
" and when they contain an `else` block, remove the latter too.
if !has('nvim')
    set stl=%!statusline#main()
endif

" Autocmds {{{1

augroup my_statusline
    au!

    " The lower the priority, the closer to the right end of the tab line the item is.
    " Warning: If you highlight a flag, make sure to reset it with `%#StatusLineTermNC#` at the end.
    au User MyFlags call statusline#hoist('global',
        \ '%6{!exists("#auto_save_and_read") && exists("g:autosave_on_startup") ? "[NAS]" : ""}', 10)
    au User MyFlags call statusline#hoist('global', '%9{&ve is# "all" ? "[ve=all]" : ""}', 20)
    au User MyFlags call statusline#hoist('global', '%16{&dip =~# "iwhiteall" ? "[dip~iwhiteall]" : ""}', 30)
    " Why an indicator for the 'paste' option?{{{
    "
    " Atm there's an issue  in Nvim, where `'paste'` may be  wrongly set when we
    " paste  some text  on the  command-line  with a  trailing literal  carriage
    " return.
    "
    " Anyway, this is  an option which has too many  effects; we need to
    " be informed immediately whenever it's set.
    "}}}
    au User MyFlags call statusline#hoist('global', '%2*%{&paste ? "[paste]" : ""}%#StatusLineTermNC#', 40)

    " The lower the priority, the closer to the left end of the status line the item is.
    " Why the arglist at the very start?{{{
    "
    " So that the index is always in the same position.
    " Otherwise, when you traverse the arglist, the index position changes every
    " time the length of the filename  also changes; this is jarring when you're
    " traversing fast and you're looking for a particular index.
    "}}}
    au User MyFlags call statusline#hoist('buffer', '%a', 10)
    au User MyFlags call statusline#hoist('buffer', ' %1*%{statusline#tail_of_path()}%* ', 20)
    au User MyFlags call statusline#hoist('buffer', '%-5r', 30)
    au User MyFlags call statusline#hoist('buffer', '%-6{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 40)
    au User MyFlags call statusline#hoist('buffer', '%{statusline#fugitive()}', 50)
    au User MyFlags call statusline#hoist('buffer',
        \ '%2*%{&mod && bufname("%") != "" && &bt isnot# "terminal" ? "[+]" : ""}%*', 60)

    " The lower the priority, the closer to the right end of the status line the item is.
    au User MyFlags call statusline#hoist('window', '%4p%% ', 10)
    au User MyFlags call statusline#hoist('window', '%-8(%.5l,%.3v%)', 20)
    au User MyFlags call statusline#hoist('window', '%-7{&l:diff ? "[diff]" : ""}', 30)
    au User MyFlags call statusline#hoist('window', '%-6{&l:pvw ? "[pvw]" : ""}', 40)

    " Purpose:{{{
    "
    " We use the tab  line to display some flags telling  us whether some global
    " options are set.
    " For some reason, the tab line is not automatically redrawn when we (re)set
    " an option (contrary  to the status line). We want to  be informed *as soon
    " as* these options are (re)set.
    "}}}
    " TODO: If we add or remove flags from the tab line, we may need to edit the pattern. This is brittle.{{{
    "
    " Once you have a mechanism emulating `vim-flagship`, and you can "register"
    " flag via a `User MyFlag` autocmd,  try to register the flags via autocmds;
    " then make the plugin inspect all global flags and extract the option names
    " to build the pattern dynamically.
    "}}}
    au OptionSet diffopt,paste,virtualedit redrawt

    au CmdWinEnter * let &l:stl = '%=%-13l'
    if has('nvim')
        " Which alternative to these autocmds could I use?{{{
        "
        " You could leverage the fact that `winnr()` evaluates to the number of:
        "
        "    - the active window in a `%!` expression
        "    - the window to which the status line belongs in an `%{}` expression
        "
        " The comparison between the two evaluations tells you whether you're in
        " an active  or inactive  window at  the time  the function  setting the
        " status line contents is invoked.
        "
        " And to  avoid having to re-evaluate  `winnr()` every time you  need to
        " know whether you're  in an active or inactive window,  you can use the
        " first `%{}` to set a window variable.
        "
        " MWE:
        "
        "     $ vim -Nu <(cat <<'EOF'
        "     " here `winnr()` is the number of the *active* window
        "     set stl=%!GetStl(winnr())
        "
        "     fu GetStl(nr) abort
        "       return '%{SetStlFlag('..a:nr..')} %{w:is_active ? "active" : "inactive"}'
        "     endfu
        "
        "     fu SetStlFlag(nr) abort
        "     " here `winnr()` is the number of the window to which the status line belongs
        "       return get(extend(w:, {'is_active': (winnr() == a:nr)}), '', '')
        "     endfu
        "     EOF
        "     ) +vs
        "
        " Source: https://github.com/vim/vim/issues/4406#issuecomment-495496763
        "}}}
        "   What is its limitation?{{{
        "
        " The  function can  only  know whether  it's called  for  an active  or
        " inactive  window inside  a  `%{}` expression;  but  inside, you  can't
        " include a `%w`, `%p`, ...:
        "
        "     %{w:is_active ? "" : "%w"}
        "                           ^^
        "                           ✘
        "
        " As a workaround, you can try to emulate them:
        "
        "     %{w:is_active ? "" : (&l:pvw ? "[Preview]" : "")}
        "
        " But that's not always easy, and it seems awkward/cumbersome.
        "}}}
        au BufWinEnter,WinEnter * setl stl=%!statusline#main(1)
        au WinLeave             * setl stl=%!statusline#main(0)

        " no `WinEnter` / `BufWinEnter` is fired right after the creation of a `UnicodeTable` buffer
        au BufDelete UnicodeTable setl stl=%!statusline#main(1)
    augroup END
endif

" Functions {{{1
fu statusline#hoist(scope, flag, ...) abort "{{{2
    unlockvar! s:flags_db
    if index(s:SCOPES, a:scope) == -1
        throw '[statusline] "'..a:scope..'" is not a valid scope'
    endif
    let s:flags_db[a:scope] += [{
        \ 'flag': a:flag,
        \ 'priority': get(a:, '1', 0),
        \ }]
    lockvar! s:flags_db
endfu

" Get flags from third-party plugins.
const s:SCOPES = ['global', 'tabpage', 'buffer', 'window']
let s:flags_db = {'global': [], 'tabpage': [], 'buffer': [], 'window': []}
let s:flags = {'global': '', 'tabpage': '', 'buffer': '', 'window': ''}
au! my_statusline VimEnter * if exists('#User#MyFlags')
    \ | do <nomodeline> User MyFlags
    \ | call s:build_flags()
    \ | endif

fu s:build_flags() abort
    for scope in keys(s:flags)
        let s:flags[scope] = sort(deepcopy(s:flags_db[scope]),
            \ {a,b -> a.priority - b.priority})
        if scope is# 'global' || scope is# 'window'
            call reverse(s:flags[scope])
        endif
        let s:flags[scope] = join(map(s:flags[scope],
            \ {_,v -> v.flag}
            \ ), '')
    endfor
    lockvar! s:flags | unlet! s:flags_db
endfu

" statusline {{{2
if !has('nvim')
    fu statusline#main() abort
        if g:statusline_winid != win_getid()
            let winnr = win_id2win(g:statusline_winid)
            return ' %1*%{statusline#tail_of_path()}%* '
               \ ..'%='
               \ ..'%-6{&l:pvw ? "[pvw]" : ""}'
               \ ..'%-7{&l:diff ? "[diff]" : ""}'
               \ ..(getwinvar(winnr, '&pvw', 0) ? '%p%% ' : '')
        else
            " How to make sure two consecutive items are separated by a space?{{{
            "
            " If they have a fixed length (e.g. 12):
            "
            "     %-13{item}
            "      ├─┘
            "      └ make the length of the item is one cell longer than the text it displays
            "        and left-align the item
            "
            " Otherwise append a space manually:
            "
            "     '%{item} '
            "             ^
            "
            " The first syntax  is better, because the space is  appended on the
            " condition the  item is not empty;  the second syntax adds  a space
            " unconditionally.
            "}}}
            " About the positions of the indicators.{{{
            "
            " Everything which is tied to:
            "
            "    - a buffer should be on the left of the status line
            "    - a window should be on the right of the status line
            "    - a tab page should be on the right of a tab label
            "    - nothing in particular should be at the start of the tab line
            "
            " When several flags must be displayed in the same location, put the
            " less  volatile  first (to  avoid  many  flags  to "dance"  when  a
            " volatile flag is frequently hidden/displayed).
            " Exception: On  the right  of the  status  line, I  think the  most
            " volatile flags should be on the left...
            "
            " That's what `vim-flagship` does, and it makes sense.
            " In particular, by default, the Vim status line puts buffer-related
            " info on the left of the status line, and the window-related one on
            " the right; let's respect this convention.
            "
            " ---
            "
            " Let the modified flag (`[+]`) at the end of the left part of the status line.
            "
            "     \       ..'%2*%{&modified && ... ? "[+]" : ""}%*'
            "
            " If  you move  it before,  then you'll  need to  append a  space to
            " separate the flag from the next one:
            "
            "     \       ..'%2*%{&modified && ... ? "[+] " : ""}%*'
            "                                            ^
            "
            " But the space will be highlighted, which we don't want.
            " So, you'll need to move it outside `%{}`:
            "
            "     \       ..'%2*%{&modified && ... ? "[+]" : ""}%* '
            "                                                     ^
            "
            " But this means that the space  will be included in the status line
            " UNconditionally. As  a result,  when the  buffer is  not modified,
            " there will be  2 spaces between the flags  surrounding the missing
            " `[+]`.
            "
            " Besides, this is probably the most volatile flag.
            "}}}
            " TODO: Try to remove all plugin-specific flags.{{{
            "
            " Atm, `vim-fex` relies on  `vim-statusline` to correctly display
            " – in the status line – the name of the directory whose contents
            " is being viewed.
            "
            " That is not good.
            " Our plugins should have as few dependencies as possible.
            " A `fex_tree` buffer should set its own status line.
            "
            " Make sure no other plugin relies on `vim-statusline` to set its
            " status line.
            "
            " ---
            "
            " We refer to `fex_tree` (and other plugins?) in other functions:
            " `statusline#tabpage_label`, `statusline#tail_of_path`.
            "}}}
            " TODO: Review the positioning/ordering of all our flags{{{
            "
            " In  particular,  look  for  `User MyFlags`  everywhere  and  check
            " whether we  specified a priority;  if we  didn't, can it  cause an
            " issue?
            "}}}
            return s:flags.buffer
                \ ..'%='
                \ ..s:flags.window
        endif
    endfu
    " %<{{{
    "
    " It means: "do *not* truncate what comes before".
    " If needed, Vim can truncate what comes after; and if it does, it truncates
    " the start of the text, not the end:
    "
    "     $ vim -Nu NONE +'set ls=2|set stl=abcdef%<ghijklmnopqrstuvwxyz' +'10vs'
    "     abcdef<xyz~
    "
    " Notice how  the text `ghi...xyz`  has been  truncated from the  start, not
    " from the end. This  is why `<` was  chosen for the item `%<`,  and this is
    " why `<` is positioned *before* the truncated text.
    "
    " However, if the text that comes before  `%<` is too long, Vim will have to
    " truncate it:
    "
    "     $ vim -Nu NONE +'set ls=2|set stl=abcdefghijklmn%<opqrstuvwxyz' +'10vs'
    "     abcdefghi>~
    "
    " Notice that this time, `>` is positioned *after* the truncated text.
    "
    " ---
    "
    " To control truncations, you must use:
    "
    "    - `%<` outside `%{}`
    "    - `.123` inside `%{}` (e.g. `%.123{...}`)
    "}}}
    " %(%) {{{
    "
    " Useful to set the desired width / justification of a group of items.
    "
    " Example:
    "
    "      ┌ left justification
    "      │ ┌ width of the group
    "      │ │
    "      │ │ ┌ various items inside the group (%l, %c, %V)
    "      │ │ ├─────┐
    "     %-15(%l,%c%V%)
    "     │           ├┘
    "     │           └ end of group
    "     │
    "     └ beginning of group
    "       the percent is separated from the open parenthesis because of the width field
    "
    " For more info, `:h 'stl`:
    "
    " > ( - Start of item group.  Can  be used for setting the width and alignment
    " >                           of a section.  Must be followed by %) somewhere.
    "
    " > ) - End of item group.    No width fields allowed.
    "}}}
    " -123  field {{{

    " Set the width of a field to 123 cells.
    "
    " Can be used (after the 1st percent sign) with all kinds of items:
    "
    "    - `%l`
    "    - `%{...}`
    "    - `%(...%)`
    "
    " Useful to append a space to an item, but only if it's not empty:
    "
    "     %-12item
    "         ├──┘
    "         └ suppose that the width of the item is 11
    "
    " The width  of the field  is one unit  greater than the one  of the item,  so a
    " space will be added; and the left-justifcation  will cause it to appear at the
    " end (instead of the beginning).
    "}}}
    " .123  field {{{
    "
    " Limit the width of an item to 123 cells:
    "
    "     %.123item
    "
    " Can be used (after the 1st percent sign) with all kinds of items:
    "
    "    - `%l`
    "    - `%{...}`
    "    - `%(...%)`
    "
    " Truncation occurs with:
    "
    "    - a '<' at the start for text items
    "    - a '>' at the end for numeric items (only `maxwid - 2` digits are kept)
    "      the number after '>' stands for how many digits are missing
    "}}}
    " What's the difference between `g:statusline_winid` and `g:actual_curwin`?{{{
    "
    " The former can be used in an `%!` expression, the latter inside a `%{}` item.
    " Note that, inside a `%{}` expression:
    "
    "     g:actual_curwin == win_getid()
    "
    " So, it's only useful to avoid the  overhead created by the invocation of a
    " Vimscript function.
    "}}}

else
    " Do *not* assume that the expression for non-focused windows will be evaluated only in the window you leave. {{{
    "
    " `main(1)` will be evaluated only for the window you focus.
    " But `main(0)` will be evaluated for ANY window which doesn't have the focus.
    " And `main(0)` will be evaluated every time the status lines must be redrawn,
    " which happens every time you change the focus from a window to another.
    "
    " This means that when you write the first expression:
    "
    "     if !a:has_focus
    "         return 1st_expr
    "     endif
    "
    " ... you must NOT assume that the  expression will only be evaluated in the
    " previous window. It will be evaluated  inside ALL windows which don't have
    " the focus, every time you change the focused window.
    "
    " This means that, if you want to reliably test a (buffer/window-)local variable:
    "
    "    - you NEED a `%{}`              in the expression for the non-focused windows
    "    - you CAN work without a `%{}`  in the expression for the     focused window
    "
    " This  explains  why you  can  test  `&ft` outside  a  `%{}`  item in  the  2nd
    " expression, but not in the first:
    "
    "     if !has_focus
    "         ✘
    "         return '...'.(&bt is# 'quickfix' ? '...' : '')
    "     endif
    "     ✔
    "     return &bt is# 'quickfix'
    "     ?...
    "     :...
    "
    "
    "     if !has_focus
    "         ✔
    "         return '...%{&bt is# 'quickfix' ? "..." : ""}'
    "     endif
    "     ✔
    "     return &bt is# 'quickfix'
    "     ?...
    "     :...
    "}}}
    fu statusline#main(has_focus) abort
        if !a:has_focus
            return ' %1*%{statusline#tail_of_path()}%* '
               \ ..'%='
               \ ..'%-6{&l:pvw ? "[pvw]" : ""}'
               \ ..'%-7{&l:diff ? "[diff]" : ""}'
               \ ..'%{&l:pvw ? float2nr(100.0 * line(".")/line("$")).."% " : ""}'
        else
            return s:flags.buffer
               \ ..'%='
               \ ..s:flags.window
        endif
    endfu
endif

fu statusline#tabline() abort "{{{2
    let s = ''
    let curtab = tabpagenr()
    let lasttab = tabpagenr('$')
    for i in range(1, lasttab)
        " color the label  of the current tab page with  the HG `TabLineSel` the
        " others with `TabLine`
        let s ..= i == curtab ? '%#TabLineSel#' : '%#TabLine#'

        " set the tab page nr (used by the mouse to recognize the tab page on which we click)
        " If you can't create enough tab pages because of `E541`,{{{
        "
        " you may want  to comment this line  to reduce the number  of `%` items
        " used in `'tal'` which will increase the limit.
        "}}}
        let s ..= '%'..i..'T'

        " set the label
        let s ..= ' %{statusline#tabpage_label('..i..')} '
        "\ append possible flag
        \ ..s:flags.tabpage
        "\ append separator before the next label
        \ ..(i != lasttab ? '│' : '')
    endfor

    " color the rest of the line with TabLineFill and reset tab page nr
    let s ..= '%#TabLineFill#%T'

    " append global flags
    let s ..= '%=%#StatusLineTermNC#'..s:flags.global

    " If you want to get a closing label, try this:{{{
    "
    "                        ┌ %X    = closing label
    "                        │ 999   = nr of the tab page to close when we click on the label
    "                        │         (big nr = last tab page currently opened)
    "                        │ close = text to display
    "                        ├────────┐
    " let s ..= '%=%#TabLine#%999Xclose'
    "            ├┘
    "            └ right-align next labels
    "}}}
    return s
endfu
" What does `statusline#tabline()` return ?{{{
"
" Suppose we have 3 tab pages, and the focus is currently in the 2nd one.
" The value of `'tal'` could be similar to this:
"
"     %#TabLine#%1T %{MyTabLabel(1)}
"     %#TabLineSel#%2T %{MyTabLabel(2)}
"     %#TabLine#%3T %{MyTabLabel(3)}
"     %#TabLineFill#%T%=%#TabLine#%999Xclose
"
" Rules:
"
" - any item must begin with `%`
" - an expression must be surrounded with `{}`
" - the HGs must be surrounded with `#`
" - we should only use one of the 3 following HGs, to highlight:
"
"    ┌─────────────────────────┬─────────────┐
"    │ the non-focused labels  │ TabLine     │
"    ├─────────────────────────┼─────────────┤
"    │ the focused label       │ TabLineSel  │
"    ├─────────────────────────┼─────────────┤
"    │ the rest of the tabline │ TabLineFill │
"    └─────────────────────────┴─────────────┘
"}}}

fu statusline#tabpage_label(n) abort "{{{2
    let [curtab, lasttab] = [tabpagenr(), tabpagenr('$')]

    " no more than `x` labels on the right/left of the label currently focused
    let x = 1
    " Shortest Distance From Ends
    let sdfe = min([curtab - 1, lasttab - curtab])
    " How did you get this expression?{{{
    "
    " We don't want to see a label for a tab page which is too far away:
    "
    "     if abs(curtab - a:n) > max_dist | return '' | endif
    "                            ^^^^^^^^
    "
    " Now, suppose we  want to see 2 labels  on the left and right  of the label
    " currently focused, but not more:
    "
    "     if abs(curtab - a:n) > 2 | return '' | endif
    "                            ^
    "
    " If we're in the middle of a big enough tabline, it will look like this:
    "
    "       | | | a | a | A | a | a | | |
    "                 │   │
    "                 │   └ label currently focused
    "                 └ some label
    "
    " Problem:
    "
    " Suppose we focus the last but two tab page, the tabline becomes:
    "
    "     | | | a | a | A | a | a
    "
    " Now suppose we focus the last but one tab page, the tabline becomes:
    "
    "     | | | | a | a | A | a
    "
    " Notice how the tabline  only contains 4 named labels, while  it had 5 just
    " before.   We want  the tabline  to always  have the  same amount  of named
    " labels, here 5:
    "
    "     | | | a | a | a | A | a
    "           ^
    "           to get this one we need `max_dist = 3`
    "
    " It appears that focusing the last but  one tab page is a special case, for
    " which `max_dist` should be `3` and not `2`.
    " Similarly, when we focus  the last tab page, we need  `max_dist` to be `4`
    " and not `2`:
    "
    "     | | | a | a | a | a | A
    "           ^   ^
    "           to get those, we need `max_dist = 4`
    "
    " So, we need to add a number to `2`:
    "
    "    ┌──────────────────────────────────────────┬──────────┐
    "    │              where is focus              │ max_dist │
    "    ├──────────────────────────────────────────┼──────────┤
    "    │ not on last nor on last but one tab page │ 2+0      │
    "    ├──────────────────────────────────────────┼──────────┤
    "    │ on last but one tab page                 │ 2+1      │
    "    ├──────────────────────────────────────────┼──────────┤
    "    │ on last tab page                         │ 2+2      │
    "    └──────────────────────────────────────────┴──────────┘
    "
    " But what is the expression to get this number?
    " Answer:
    " We need to consider two cases depending on whether `lasttab - curtab >= 2`
    " is true or false.
    "
    " If it's true, it  means that we're not near enough the  end of the tabline
    " to worry; we are in the general case for which `max_dist = 2` is correct.
    "
    " If it's false, it means that we're too  close from the end, and we need to
    " increase `max_dist`.
    " By how much? The difference between the operands:
    "
    "     2 - (lasttab - curtab)
    "
    " The pseudo-code to get `max_dist` is thus:
    "
    "     if lasttab - curtab >= 2
    "         max_dist = 2
    "     else
    "         max_dist = 2 + (2 - (lasttab - curtab))
    "
    " Now we also need to handle the case where we're too close from the *start*
    " of the tabline:
    "
    "     if curtab - 1 >= 2
    "         max_dist = 2
    "     else
    "         max_dist = 2 + (2 - (curtab - 1))
    "
    " Finally, we have to merge the two snippets:
    "
    "     sdfe = min([curtab - 1, lasttab - curtab])
    "     if sdfe >= 2
    "         max_dist = 2
    "     else
    "         max_dist = 2 + (2 - sdfe)
    "
    " Which can be generalized to an arbitrary number of labels, by replacing `2` with `x`:
    "
    "     sdfe = min([curtab - 1, lasttab - curtab])
    "     if sdfe >= x
    "         max_dist = x
    "     else
    "         max_dist = x + (x - sdfe)
    "}}}
    let max_dist = x + (sdfe >= x ? 0 : x - sdfe)
    " Alternative:{{{
    " for 3 labels:{{{
    "
    "     let max_dist =
    "     \   index([1, lasttab], curtab) != -1 ? 1+1
    "     \ :                                     1+0
    "}}}
    " for 5 labels:{{{
    "
    "     let max_dist =
    "     \   index([1, lasttab],   curtab) != -1 ? 2+2
    "     \ : index([2, lasttab-1], curtab) != -1 ? 2+1
    "     \ :                                       2+0
    "}}}
    " for 7 labels:{{{
    "
    "     let max_dist =
    "     \   index([1, lasttab],   curtab) != -1 ? 3+3
    "     \ : index([2, lasttab-1], curtab) != -1 ? 3+2
    "     \ : index([3, lasttab-2], curtab) != -1 ? 3+1
    "     \ :                                       3+0
    "}}}
    "}}}

    if abs(curtab - a:n) > max_dist | return a:n | endif

    "             ┌ I give you the nr of a tab page
    "             ├─────┐
    let buflist = tabpagebuflist(a:n)
    "                    ├─────┘
    "                    └ give me its buffer list:
    "                      for each window in the tab page, the function
    "                      adds the nr of the buffer that it displays
    "                      inside a list, and returns the final list
    "
    let winnr = tabpagewinnr(a:n)
    "                  ├───┘
    "                  └ give me the number of its focused window

    let bufnr = buflist[winnr - 1]

    "          ┌ I give you the nr of a buffer
    "          ├─┐
    let name = bufname(bufnr)
    "             ├──┘
    "             └ give me its name

    " Alternative to `get(b:, 'qf_is_loclist', 0)` :
    "
    "     get(get(getwininfo(win_getid(winnr, a:n)), 0, {}), 'loclist', 0)

    let label = getbufvar(bufnr, '&bt', '') is# 'terminal'
       \ ?     '[term]'
       \ : name[-1:] is# '/'
       \ ?     fnamemodify(name, ':h:t')..'/'
       \ : getbufvar(bufnr, '&bt') is# 'quickfix'
       \ ?     getbufvar(bufnr, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
       \ : name =~# '^/tmp/.*/fex_tree$'
       \ ?     '└ /'
       \ : name =~# '^/tmp/.*/fex_tree'
       \ ?     '└ '..fnamemodify(name, ':t')
       \ :     fnamemodify(name, ':t')
    " Format the label so that it never exceeds 10 characters, and is centered.{{{
    "
    " This  is useful  to prevent  the tabline  from "dancing"  when we  focus a
    " different window in the same tab page  (e.g. happens when you focus the qf
    " window, or leave it).
    "}}}
    " What about multibyte characters?{{{
    "
    " Yes, we should write sth like:
    "
    "     let label = matchstr(label, repeat('.', '10'))
    "     let len = strchars(label, 1)
    "
    " But I'm concerned about the impact on Vim's performance.
    " I don't know how often this function is evaluated.
    " Anyway,  we will  rarely edit  files  with multibyte  characters in  their
    " names...
    "}}}
    let label = label[:9]
    let len = len(label)
    let cnt = (10 - len)/2
    return repeat(' ', cnt)..label..repeat(' ', cnt+len%2)
endfu

fu statusline#tail_of_path() abort "{{{2
    let tail = fnamemodify(@%, ':t')

    return &bt is# 'terminal'
       \ ?     '[term]'
       \ : tail =~# '^diffpanel_\d\+$'
       \ ?     ''
       \ :  expand('%:p') =~# '^fugitive://'
       \ ?     '[fgt]'
       \ : tail is# ''
       \ ?     (&bt is# 'nofile' ? '[Scratch]' : '[No Name]')
       \ :     tail
endfu
" The following comment is kept for educational purpose, but no longer relevant.{{{
" It applied to a different expression than the one currently used. Sth like:
"
"     return &bt  isnot#  'terminal'
"        \ ? &ft  isnot#  'dirvish'
"        \ ? &bt  isnot#  'quickfix'
"        \ ? tail isnot# ''
"        \ ?     tail
"        \ :     '[No Name]'
"        \ :     b:qf_is_loclist ? '[LL]' : '[QF]'
"        \ :     '[dirvish]'
"        \ :     '[term]'
"}}}
" How to read the returned expression:{{{
"
"    - pair the tests and the values as if they were an imbrication of parentheses
"
"      Example:
"
"         1st test    =    &bt isnot# 'terminal'
"         last value  =    [term]
"
"         2nd test           =    &filetype isnot# 'dirvish'
"         penultimate value  =    [dirvish]
"
"         ...
"
"     - when a test fails, the returned value is immediately known:
"       it's the one paired with the test
"
"     - when a test succeeds, the next test is evaluated:
"       all the previous ones are known to be true
"
"     - If all tests succeed, the value which is used is `tail`.
"       It's the only one which isn't paired with any test.
"       It means that it's used iff all the tests have NOT failed.
"       It's the default value used for a buffer without any peculiarity:
"       random type, random name
"}}}

fu statusline#fugitive() abort "{{{2
    if !get(g:, 'my_fugitive_branch', 0)
        return ''
    endif
    return exists('*fugitive#statusline') ? fugitive#statusline() : ''
endfu
"}}}1
