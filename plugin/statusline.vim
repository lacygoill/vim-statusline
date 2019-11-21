if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

const s:MAX_LIST_SIZE = 999

" FIXME: When we press  `C-l` in insert mode, the flag  `[Caps]` is displayed in
" the status line (✔); but the cursor jumps in the status line (✘).
" The issue is specific to Vim, not Nvim.

" TODO: Read the following links to improve the statusline.{{{

" Blog post talking about status line customization:
" http://www.blaenkdenum.com/posts/a-simpler-vim-statusline

" Vim Powerline-like status line without the need of any plugin:
" https://gist.github.com/ericbn/f2956cd9ec7d6bff8940c2087247b132
"}}}
" TODO: If possible, make the `%{statusline#list_position()}` item local to the current window.{{{
"
" For inspiration, study `vim-flagship` first.
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

    " Warning: If you highlight a flag, make sure to reset it with `%#StatusLineTermNC#` at the end.
    " Why an indicator for the 'paste' option?{{{
    "
    " Atm there's an issue  in Nvim, where `'paste'` may be  wrongly set when we
    " paste  some text  on the  command-line  with a  trailing literal  carriage
    " return.
    "
    " Anyway, this is  an option which has too many  effects; we need to
    " be informed immediately whenever it's set.
    "}}}
    au User MyFlags call statusline#hoist('global', '%2*%{&paste ? "[paste]" : ""}%#StatusLineTermNC#', 1)
    au User MyFlags call statusline#hoist('global', '%16{&dip =~# "iwhiteall" ? "[dip~iwhiteall]" : ""}', 2)
    au User MyFlags call statusline#hoist('global', '%9{&ve is# "all" ? "[ve=all]" : ""}', 3)
    au User MyFlags call statusline#hoist('global',
        \ '%6{!exists("#auto_save_and_read") && exists("g:autosave_on_startup") ? "[NAS]" : ""}', 4)

    au User MyFlags call statusline#hoist('buffer', ' %1*%{statusline#tail_of_path()}%* ', 1)
    au User MyFlags call statusline#hoist('buffer', '%-5r', 2)
    au User MyFlags call statusline#hoist('buffer', '%{statusline#list_position()}', 3)
    au User MyFlags call statusline#hoist('buffer', '%-6{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 4)
    au User MyFlags call statusline#hoist('buffer', '%{statusline#fugitive()}', 5)
    au User MyFlags call statusline#hoist('buffer',
        \ '%2*%{&mod && bufname("%") != "" && &bt isnot# "terminal" ? "[+]" : ""}%*', 6)

    au User MyFlags call statusline#hoist('window', '%-6{&l:pvw ? "[pvw]" : ""}', 1)
    au User MyFlags call statusline#hoist('window', '%-7{&l:diff ? "[diff]" : ""}', 2)
    au User MyFlags call statusline#hoist('window', '%-8(%.5l,%.3v%)', 3)
    au User MyFlags call statusline#hoist('window', '%4p%% ', 4)

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

    if !has('nvim')
        " remove local value set by default (filetype) plugins
        au Filetype undotree,qf set stl<
        " just show the line number in a command-line window
        au CmdWinEnter * let &l:stl = '%=%-13l'
        " same thing in some special files
        au FileType tmuxprompt,websearch let &l:stl = '%y%=%-13l'
    else
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
        "                          ^^^
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

        " Why?{{{
        "
        " Needed for some special buffers, because no `WinEnter` / `BufWinEnter`
        " is fired right after their creation.
        "}}}
        " But, isn't there a `(Buf)WinEnter` after populating the qfl and opening its window?{{{
        "
        " Yes, but if  you close the window, then later  re-open it, there'll be
        " no `(Buf)WinEnter`. OTOH, there will be a `FileType`.
        "}}}
        au Filetype  dirvish,man,qf setl stl=%!statusline#main(1)
        au BufDelete UnicodeTable   setl stl=%!statusline#main(1)

        au CmdWinEnter * let &l:stl = '%=%-13l'
        " Why `WinEnter` *and* `BufWinEnter`?{{{
        "
        " `BufWinEnter` for when the buffer is displayed for the first time.
        " `WinEnter` for when we move to another window, then come back.
        "}}}
        " Why not `FileType`?{{{
        "
        " Because there's a `BufWinEnter` after `FileType`.
        " And  we have  an autocmd  listening to  `BufWinEnter` which  would set
        " `'stl'` with the value `%!statusline#main(1)`.
        "}}}
        au WinEnter,BufWinEnter tmuxprompt,websearch let &l:stl = '%y%=%-13l'
    augroup END
endif

" Public Functions {{{1
fu statusline#hoist(scope, flag, ...) abort "{{{2
    unlockvar! s:flags_db
    if index(s:SCOPES, a:scope) == -1
        throw '[statusline] "'..a:scope..'" is not a valid scope'
    endif
    if a:scope is# 'buffer' || a:scope is# 'window'
        " TODO: I think we should get rid of this `ft` key.{{{
        "
        " It makes the code complex.
        " Besides, I don't think we need it.
        " You want a different status line in a given type of file?
        " Just set the local value of `'stl'` from a filetype plugin.
        "
        " Note that this should work with Vim, because in the latter we only set
        " the global value of `'stl'`.
        " However, it  will be more  complex in Nvim,  because in the  latter we
        " already  set the  local value  of  `'stl'` via  autocmds listening  to
        " `WinEnter`/`WinLeave`/....
        " But  it should  still  be possible:  try to  install  autocmds from  a
        " filetype plugin with the pattern `<buffer>`.
        "}}}
        let ft = get(get(a:, '2', {}), 'ft', 'any')
        if !has_key(s:flags_db[a:scope], ft)
            let s:flags_db[a:scope][ft] = []
        endif
        " TODO: Remove duplication of code
        let s:flags_db[a:scope][ft] += [{
            \ 'flag': a:flag,
            \ 'priority': get(a:, '1', 0),
            \ }]
    else
        let s:flags_db[a:scope] += [{
            \ 'flag': a:flag,
            \ 'priority': get(a:, '1', 0),
            \ }]
    endif
    lockvar! s:flags_db
endfu

" Get flags from third-party plugins.
const s:SCOPES = ['global', 'tabpage', 'buffer', 'window']
let s:flags_db = {'global': [], 'tabpage': [], 'buffer': {'any': []}, 'window': {'any': []}}
let s:flags = {'global': '', 'tabpage': '', 'buffer': {'any': []}, 'window': {'any': []}}
au! my_statusline VimEnter * if exists('#User#MyFlags')
    \ | do <nomodeline> User MyFlags
    \ | call s:build_flags()
    \ | endif

fu s:build_flags() abort
    for scope in keys(s:flags)
        if scope is# 'buffer' || scope is# 'window'
            for filetype in keys(s:flags_db[scope])
                " TODO: Remove duplication of code
                let s:flags[scope][filetype] = join(map(sort(deepcopy(s:flags_db[scope][filetype]),
                    \ {a,b -> a.priority - b.priority}),
                    \ {_,v -> v.flag}
                    \ ), '')
            endfor
        else
            let s:flags[scope] = join(map(sort(deepcopy(s:flags_db[scope]),
            \ {a,b -> a.priority - b.priority}),
            \ {_,v -> v.flag}
            \ ), '')
        endif
    endfor
    lockvar! s:flags | unlet! s:flags_db
endfu

" statusline {{{2
if !has('nvim')
    fu statusline#main() abort
        if g:statusline_winid != win_getid()
            let winnr = win_id2win(g:statusline_winid)
            return getwinvar(winnr, '&ft', '') is# 'undotree'
                \ ?     '%=%l/%L '
                \ :     ' %1*%{statusline#tail_of_path()}%* '
                \     ..'%='
                \     ..'%-6{&l:pvw ? "[pvw]" : ""}'
                \     ..'%-7{&l:diff ? "[diff]" : ""}'
                \     ..(getwinvar(winnr, '&pvw', 0) ? '%p%% ' : '')
                \     ..(getwinvar(winnr, '&bt', '') is# 'quickfix' ? '%-15(%l/%L%) ' : '')
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
            " TODO: Maybe we should remove all plugin-specific flags.{{{
            "
            " Instead, we could register a flag from a plugin via a public function.
            "
            " For inspiration, have a look at this:
            " https://github.com/tpope/vim-flagship/blob/master/doc/flagship.txt#L33
            "
            " ---
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
            return get(s:flags.buffer, &ft, s:flags.buffer.any)
            \    ..'%='
            \    ..get(s:flags.window, &ft, s:flags.window.any)
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
            return  ' %1*%{&ft isnot# "undotree" ? statusline#tail_of_path() : ""}%* '
                \ ..'%='
                \ ..'%{line(".").."/"..line("$")} '
                \ ..'%-6{&l:pvw ? "[pvw]" : ""}'
                \ ..'%-7{&l:diff ? "[diff]" : ""}'
                \ ..'%{&l:pvw ? float2nr(100.0 * line(".")/line("$")).."% " : ""}'
                \ ..'%{&bt is# "quickfix"
                \      ?     line(".").."/"..line("$")..repeat(" ", 16 - len(line(".").."/"..line("$")))
                \      :     ""}'
        else
            return get(s:flags.buffer, &ft, s:flags.buffer.any)
            \    ..'%='
            \    ..get(s:flags.window, &ft, s:flags.window.any)
        endif
    endfu
endif

fu statusline#tabline() abort "{{{2
    " TODO: Include `s:flags.tabpage` in the labels.
    let s = ''
    let lasttab = tabpagenr('$')
    for i in range(1, lasttab)
        " color the label of the current tab page with the HG TabLineSel
        " the others with TabLine
        let s ..= i == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#'

        " set the tab page nr
        " used by the mouse to recognize the tab page on which we click
        let s ..= '%'..i..'T'

        " set the label by invoking another function `statusline#tabpage_label()`
        let s ..= ' %{statusline#tabpage_label('..i..')} '..(i != lasttab ? '│' : '')
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
       \ : &ft is# 'dirvish'
       \ ?     '[dirvish] '..expand('%:p')
       \ : &bt is# 'quickfix'
       \ ?     get(b:, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
       \ : tail is# 'fex_tree'
       \ ?     '/'
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
fu statusline#list_position() abort "{{{2
    if !get(g:, 'my_stl_list_position', 0)
        return ''
    endif

    let [s:cur_col, s:cur_line, s:cur_buf] = [col('.'),     line('.'), bufnr('%')]
    let [s:bufname, s:argidx, s:argc]      = [bufname('%'), argidx(),  argc()]

    if g:my_stl_list_position == 1 && get(getqflist({'size': 0}), 'size', 0) > s:MAX_LIST_SIZE
        return '[> '..s:MAX_LIST_SIZE..']'
    elseif g:my_stl_list_position == 2 && argc() > s:MAX_LIST_SIZE
        return '[> '..s:MAX_LIST_SIZE..']'
    endif

    let s:list = [
        \ {'name': 'qfl', 'entries': getqflist()},
        \ {'name': 'arg', 'entries': map(range(argc()), {_,v -> argv(v)})}
        \ ][g:my_stl_list_position-1]

    if empty(s:list.entries)
        return '[]'
    endif

    let info = { 'qfl': getqflist({'idx':  0, 'size': 0}),
        \        'arg': {'idx':  argidx(), 'size': argc()},
        \ }[s:list.name]

    if len(info) < 2 | return '[]' | endif

    let [idx, size] = [info.idx, info.size]
    let s:cur_entry = s:list.entries[idx-1]

    return ( s:is_in_list_and_current()()
       \ ?       {'qfl': 'C', 'arg': 'A'}[s:list.name]
       \ :   s:is_in_list_but_not_current()()
       \ ?       {'qfl': 'c', 'arg': 'a'}[s:list.name]
       \ :       {'qfl': 'ȼ', 'arg': 'ā'}[s:list.name]
       \   )
       \ ..'['..(idx + (s:list.name is# 'arg' ? 1 : 0))..'/'..size..']'
endfu

" This function displays an item showing our position in the qfl or arglist.
"
" It only works when `g:my_stl_list_position` is set to 1 (which is not the case
" by default).   To toggle  the display,  install autocmds  which set  the value
" automatically when the qfl or arglist is populated.
"
" And/or use mappings, such as:
"
"     nno  <silent>  [oi  :let g:my_stl_list_position = 1<cr>
"     nno  <silent>  ]oi  :let g:my_stl_list_position = 0<cr>
"     nno  <silent>  coi  :let g:my_stl_list_position = !get(g:, 'my_stl_list_position', 0)<cr>

fu statusline#fugitive() abort "{{{2
    if !get(g:, 'my_fugitive_branch', 0)
        return ''
    endif
    return exists('*fugitive#statusline') ? fugitive#statusline() : ''
endfu
"}}}1
" Util Functions{{{1
fu s:is_in_list_and_current() abort "{{{2
    return
    \      { 'qfl':
    \               {->
    \                        [s:cur_buf,         s:cur_line,       s:cur_col]
    \                    ==# [s:cur_entry.bufnr, s:cur_entry.lnum, s:cur_entry.col]
    \                ||
    \                        [s:cur_buf,         s:cur_line]
    \                    ==# [s:cur_entry.bufnr, s:cur_entry.lnum]
    \                    &&  s:cur_entry.col == 0
    \                ||
    \                        s:cur_buf
    \                    ==  s:cur_entry.bufnr
    \                    && [s:cur_entry.lnum, s:cur_entry.col] ==# [0, 0]
    \               },
    \
    \        'arg': {-> s:bufname is# argv(s:argidx)}
    \      }[s:list.name]
endfu

fu s:is_in_list_but_not_current() abort "{{{2
    return
    \      {'qfl':
    \              {-> index(
    \                   map(deepcopy(s:list.entries), {_,v -> [v.bufnr, v.lnum, v.col]}),
    \                   [s:cur_buf, s:cur_line, s:cur_col]) >= 0
    \              },
    \
    \       'arg': {-> index(map(range(s:argc), {_,v -> argv(v)}), s:bufname) >= 0}
    \      }[s:list.name]
endfu
" }}}1
