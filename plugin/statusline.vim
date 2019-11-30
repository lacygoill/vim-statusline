if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

" FAQ {{{1
" What's the meaning of ...?{{{2
" %<{{{3
"
" It means: "you can truncate what comes right after".
"
"     $ vim -Nu NONE +'set ls=2|set stl=abcdef%<ghijklmnopqrstuvwxyz' +'10vs'
"     abcdef<xyz~
"
" Notice how  the *start* of  the text `ghi...xyz`  has been truncated,  not the
" end. This is why `<`  was chosen for the item `%<` (and not  `>`), and this is
" why `<` is positioned *before* the truncated text.
"
" However, if  the text that  comes before  `%<` is too  long, Vim will  have to
" truncate it too:
"
"     $ vim -Nu NONE +'set ls=2 stl=abcdefghijklmn%<opqrstuvwxyz' +'10vs'
"     abcdefghi>~
"
" Notice  that  this time,  it's  the  *end* of  the  *previous*  text which  is
" truncated, and that `>` is positioned after it.
"
" To summarize:
" `%<` describes a point from which Vim can truncate the text if needed.
" It starts by truncating as much text as necessary right *after* the point.
" If that's not enough, it goes on by truncating the text right *before* the point.
"
"     very long %< text
"
" If  "very long  text" is  too long  for  the status  line, Vim  will start  by
" truncating the start of " text":
"
"     very long %< text
"                 ---->
"                 as much as necessary
"
" and if truncating all of " text"  is not enough, it will then truncate the end
" of "very long ":
"
"     very long %< text
"     <---------
"     as much as necessary
"
" ---
"
" If you omit `%<`,  Vim assumes it's at the start, and  truncates from the very
" beginning:
"
"     $ vim -Nu NONE +'set ls=2 stl=abcdefghijklmnopqrstuvwxyz' +'10vs'
"     <rstuvwxyz~
"
" ---
"
" To control truncations, you must use:
"
"    - `%<` outside `%{}`
"    - `.123` inside `%{}` (e.g. `%.123{...}`)
"
" Note that `.123` truncates the start of the text, just like `%<`.

" %(%) {{{3
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

" -123  field {{{3

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

" .123  field {{{3
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
" How to set a flag in the tabpage scope?{{{2
"
" Like for any other scope:
"
"     au User MyFlags call statusline#hoist('tabpage', '[on]')
"
" However, if your flag depends on the tab page in which it's displayed, you may
" need the special placeholder `{tabnr}`. For  example, to include the number of
" windows inside a tab page, you would write:
"
"     au User MyFlags call statusline#hoist('tabpage', '[%{tabpagewinnr({tabnr}, "$")}]')
"                                                                       ^^^^^^^
"
" If your expression  is too complex to  fit directly in the  function call, and
" you  need to  compute the  flag via  another function,  make sure  to pass  it
" `{tabnr}` as an argument:
"                                                            vvvvvvv
"     au User MyFlags call statusline#hoist('tabpage', 'Func({tabnr})')
"     fu Func(tabnr)
"             ^^^^^
"         " compute the flag using `a:tabnr` to refer to the tab page number
"                                   ^^^^^^^
"         return '...'
"     endfu
"}}}1

" Init {{{1

" no more than `x` characters in a tab label
const s:TABLABEL_MAXSIZE = 20

" no more than `x` tab labels on the right/left of the tab label currently focused
const s:MAX_TABLABELS = 1

" HG to use to highlight the flags in the tab line
const s:HG_TAL_FLAGS = '%#StatusLineTermNC#'

const s:SCOPES = ['global', 'tabpage', 'buffer', 'window']
let s:flags_db = {'global': [], 'tabpage': [], 'buffer': [], 'window': []}
let s:flags = {'global': '', 'tabpage': '', 'buffer': '', 'window': ''}

" Options {{{1

" always show the status line and the tab line
set ls=2 stal=2

" `vim-flagship` recommends to remove the `e` flag from 'guioptions', because it:
" > disables the GUI tab line in favor of the plain text version
set guioptions-=e

set tabline=%!statusline#tabline()

" TODO: Once `8.1.1372` has been ported to Nvim, remove all the `if ! has('nvim')` guards,
" and when they contain an `else` block, remove the latter too.
if ! has('nvim')
    set stl=%!statusline#main()
endif

" Commands {{{1

com -bar -complete=custom,s:complete -nargs=? -range=% StlFlags call s:display_flags(<q-args>)

fu s:complete(_a, _l, _p) abort
    return join(s:SCOPES, "\n")
endfu

fu s:display_flags(scope) abort
    let scopes = a:scope is# '' ? s:SCOPES : [a:scope]
    let lines = []
    for scope in scopes
        " underline each `scope ...` line with a `---` line
        let lines += ['', 'scope '..scope, substitute('scope '..scope, '.', '-', 'g'), '']
        let lines += map(deepcopy(s:flags_db[scope]),
            \ {_,v -> substitute(v.flag, '\s\+$', '\=repeat("█", len(submatch(0)))', '') .."\x01".. v.priority})
        " `substitute()` makes visible a trailing whitespace in a flag

        " Purpose:{{{
        "
        " If there is one flag, and only one flag in a given scope, the flags in
        " the subsequent scopes will not be formatted correctly.
        " This is because the ranges in  our next global commands work under the
        " assumption that a scope always contains several flags.
        "
        " To fix this issue, we temporarily add a dummy flag.
        "
        " ---
        "
        " Our  global  commands still  give  the  desired  result when  a  scope
        " contains no flag.
        "}}}
        if len(s:flags_db[scope]) == 1
            let lines += ['dummy flag 123']
        endif
    endfor
    exe 'pedit '..tempname()
    wincmd P
    if ! &pvw | return | endif
    setl bt=nofile nobl noswf nowrap
    call append(0, lines)
    let range = '/^---//\d\+$/ ; /\d\+$//^\s*$\|\%$/-'
    " align priorities in a column
    sil keepj keepp g/^---/exe range.."!column -t -s\x01"
    " for each scope, sort the flags according to their priority
    sil! keepj keepp g/^---/exe range..'sort /.\{-}\ze\d\+$/ n'
    "  │
    "  └ in case the scope does not contain any flag
    sil keepj keepp g/dummy flag 123/d_
    1d_
    " highlight flags installed from third-party plugins
    call matchadd('DiffAdd', '.*[1-9]$')
    nmap <buffer><nowait><silent> q <plug>(my_quit)
endfu

" Autocmds {{{1

augroup my_statusline
    au!

    " get flags from third-party plugins
    au VimEnter * if exists('#User#MyFlags')
        \ | do <nomodeline> User MyFlags
        \ | call s:build_flags()
        \ | endif

    " How to make sure two consecutive flags A and B are visually well separated?{{{
    "
    " If the length of A is fixed (e.g. 12), and A is not highlighted:
    "
    "     %-13{item}
    "      ├─┘
    "      └ make the length of the flag one cell longer than the text it displays
    "        and left-align it
    "
    " You could also append a space manually:
    "
    "     '%{item} '
    "             ^
    "
    " But the space would be displayed unconditionally which you probably don't want.
    "
    " ---
    "
    " If the length of A is fixed, and A *is* highlighted, don't try to append a
    " space; it would get highlighted which would be ugly.
    "
    " ---
    "
    " If  the length  of A  can  vary, highlight  it  with a  HG different  than
    " `StatusLine` so that it clearly stands out.
    "}}}
    " What are the "buffer", "window", "tabpage" and "global" scopes?{{{
    "
    " A flag may give an information about:
    "
    "    - a buffer; we say it's in the *buffer scope*
    "    - a window; we say it's in the *window scope*
    "    - all buffers in a tabpage; we say it's in the *tabpage scope*
    "    - some setting which applies to all buffers/windows/tabpages; we say it's in the *global scope*
    "
    " By convention, we display a flag in:
    "
    "    - the buffer scope, on the left of the status line
    "    - the window scope, on the right of the status line
    "    - the tabpage scope, at the end of a tab label
    "    - the global scope, on the right of the tab line
    "
    " That's more or less what `vim-flagship` does.
    " This is a useful convention because it makes a flag give more information;
    " its position tells us what is affected.
    "}}}
    " What is a "volatile" flag?{{{
    "
    " For any given flag, you should consider 2 characteristics:
    "
    "    - how frequent is it displayed?
    "    - how stable is it?
    "
    " During a one-hour Vim  session, if a flag A is  displayed for ten minutes,
    " and a flag B for five minutes, A is more **frequent** than B.
    " But if A  is on for one minute,  then off for one minute, then  on for one
    " minute etc.  while B is  on for five consecutive  minutes, then B  is more
    " **stable** than A.
    "
    " The  more  stable/frequent  a  flag  is,  the more  on  the  left  of  the
    " buffer/tabpage scope  – or on  the right of  the window/global scope  – it
    " should be.
    "}}}
    " I have 2 flags A and B in the same scope.  I don't know which one should be displayed first!{{{
    "
    " Ask yourself this: how frequently could I be in a situation where B is on,
    " and the state of A changes (on → off, off → on)?
    "
    " If the answer is "often", then B should be displayed:
    "
    "    - before A if they are in the buffer/tabpage scope
    "    - after A if they are in the tabpage/global scope
    "
    " The goal is to prevent as much  as possible that a recently displayed flag
    " disturbs the positions of existing flags.
    "
    " ---
    "
    " Don't think about it too much. Tweak the priorities by experimentation.
    " If  the display  of  A often  disturbs  the position  of  B, increase  A's
    " priority so that it's greater than B's priority.
    "}}}
    " For the priorities, what type of numbers should I use?{{{
    "
    " Follow this  useful convention: any  flag installed from this  file should
    " have a priority which is a multiple of 10.
    " For flags installed from third-party plugins, use priorities which are not
    " multiples of 10.
    "}}}
    " the lower the priority, the closer to the right end of the tab line the flag is
    au User MyFlags call statusline#hoist('global',
        \ '%{!exists("#auto_save_and_read") ? "[NAS]" : ""}', 10)
    au User MyFlags call statusline#hoist('global', '%{&ve is# "all" ? "[ve=all]" : ""}', 20)
    au User MyFlags call statusline#hoist('global', '%{&dip =~# "iwhiteall" ? "[dip~iwa]" : ""}', 30)
    " Why an indicator for the 'paste' option?{{{
    "
    " Atm there's an issue  in Nvim, where `'paste'` may be  wrongly set when we
    " paste  some text  on the  command-line  with a  trailing literal  carriage
    " return.
    "
    " Anyway, this is  an option which has too many  effects; we need to
    " be informed immediately whenever it's set.
    "}}}
    au User MyFlags call statusline#hoist('global', '%2*%{&paste ? "[paste]" : ""}', 40)

    " the lower the priority, the closer to the left end of the status line the flag is
    " Why the arglist at the very start?{{{
    "
    " So that the index is always in the same position.
    " Otherwise, when you traverse the arglist, the index position changes every
    " time the length of the filename  also changes; this is jarring when you're
    " traversing fast and you're looking for a particular index.
    "}}}
    au User MyFlags call statusline#hoist('buffer', '%a', 10)
    au User MyFlags call statusline#hoist('buffer', ' %1*%{statusline#tail_of_path()}%* ', 20)
    au User MyFlags call statusline#hoist('buffer', '%r', 30)
    au User MyFlags call statusline#hoist('buffer', '%{statusline#fugitive()}', 40)
    au User MyFlags call statusline#hoist('buffer', '%{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}', 50)
    au User MyFlags call statusline#hoist('buffer',
        \ '%2*%{&mod && bufname("%") != "" && &bt !=# "terminal" ? "[+]" : ""}', 60)

    " the lower the priority, the closer to the right end of the status line the flag is
    au User MyFlags call statusline#hoist('window', '%5p%% ', 10)
    au User MyFlags call statusline#hoist('window', '%9(%.5l,%.3v%)', 20)
    au User MyFlags call statusline#hoist('window', '%{&l:pvw ? "[pvw]" : ""}', 30)
    au User MyFlags call statusline#hoist('window', '%{&l:diff ? "[diff]" : ""}', 40)

    au User MyFlags call statusline#hoist('tabpage', '%{statusline#tabpagewinnr({tabnr})}', 10)

    " Purpose:{{{
    "
    " We use the tab  line to display some flags telling  us whether some global
    " options are set.
    " For some reason, the tab line is not automatically redrawn when we (re)set
    " an option (contrary to the status  line). We want to be informed *as soon*
    " *as* these options are (re)set.
    "}}}
    au OptionSet diffopt,paste,virtualedit redrawt

    au CmdWinEnter * let &l:stl = ' %l'

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
            \ | let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')..'| set stl<'
    endif
augroup END

" Functions {{{1
fu statusline#hoist(scope, flag, ...) abort "{{{2
    unlockvar! s:flags_db
    if index(s:SCOPES, a:scope) == -1
        throw '[statusline] "'..a:scope..'" is not a valid scope'
    endif
    let flag = a:flag
    let pat = '^%[1-9]\*\|^%#[^#]\+#'
    if (a:scope is# 'global' || a:scope is# 'window') && flag =~# pat
        " if a flag is highlighted, restore normal highlight
        let flag ..= s:HG_TAL_FLAGS
    elseif (a:scope is# 'buffer' || a:scope is# 'tabpage') && flag =~# pat
        let flag ..= '%*'
    endif
    let s:flags_db[a:scope] += [{
        \ 'flag': flag,
        \ 'priority': get(a:, '1', 0),
        \ }]
    lockvar! s:flags_db
endfu

fu s:build_flags() abort
    for scope in keys(s:flags)
        let s:flags[scope] = sort(deepcopy(s:flags_db[scope]),
            \ {a,b -> a.priority - b.priority})
        if scope is# 'global' || scope is# 'window'
            call reverse(s:flags[scope])
        endif
       let s:flags[scope] = join(map(s:flags[scope], {_,v -> v.flag}), '')
    endfor
    lockvar! s:flags
endfu

" statusline {{{2
if ! has('nvim')
    fu statusline#main() abort
        if g:statusline_winid != win_getid()
            let winnr = win_id2win(g:statusline_winid)
            return ' %1*%{statusline#tail_of_path()}%* '
               \ ..'%='
               \ ..'%-6{&l:pvw ? "[pvw]" : ""}'
               \ ..'%-7{&l:diff ? "[diff]" : ""}'
               \ ..(getwinvar(winnr, '&pvw', 0) ? '%p%% ' : '')
        else
            return s:flags.buffer
                \ ..'%='
                \ ..s:flags.window
        endif
    endfu
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
    "     if ! a:has_focus
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
    "     if ! has_focus
    "         ✘
    "         return '...'.(&bt is# 'quickfix' ? '...' : '')
    "     endif
    "     ✔
    "     return &bt is# 'quickfix'
    "     ?...
    "     :...
    "
    "
    "     if ! has_focus
    "         ✔
    "         return '...%{&bt is# 'quickfix' ? "..." : ""}'
    "     endif
    "     ✔
    "     return &bt is# 'quickfix'
    "     ?...
    "     :...
    "}}}
    fu statusline#main(has_focus) abort
        if ! a:has_focus
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
    let [curtab, lasttab] = [tabpagenr(), tabpagenr('$')]
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
        " Which  can be generalized to  an arbitrary number of  labels, by replacing
        " `2` with a variable `x`:
        "
        "     sdfe = min([curtab - 1, lasttab - curtab])
        "     if sdfe >= x
        "         max_dist = x
        "     else
        "         max_dist = x + (x - sdfe)
        "}}}
        let max_dist = s:MAX_TABLABELS + (sdfe >= s:MAX_TABLABELS ? 0 : s:MAX_TABLABELS - sdfe)
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

        " set the label
        if abs(curtab - i) > max_dist
            let label = i
        else
            let flags = substitute(s:flags.tabpage, '\m\C{tabnr}', i, 'g')
            let label = ' %{statusline#tabpage_label('..i..','..curtab..')} '
                "\ append possible flags
                \ ..s:HG_TAL_FLAGS
                \ ..flags
                \ ..'%#TabLine#'
                \ ..(flags isnot# '' && i != curtab ? ' ' : '')
        endif

        " append separator before the next label
        let s ..= label..'│'
    endfor

    " color the rest of the line with `TabLineFill` (until the flags), and reset tab page nr (`%T`)
    let s ..= '%#TabLineFill#%T'

    " append global flags on the right of the tab line
    let s ..= '%='..s:HG_TAL_FLAGS..s:flags.global

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

fu statusline#tabpage_label(n, curtab) abort "{{{2
    let winnr = tabpagewinnr(a:n)
    let bufnr = winbufnr(win_getid(winnr, a:n))
    let bufname = fnamemodify(bufname(bufnr), ':p')

    " Display the cwd iff:{{{
    "
    "    - the label is for the current tab page
    "
    "      In that case, we don't care about the name of the current file:
    "
    "        - it's already in the status line
    "        - it's complete in the status line
    "
    "    - the file is in a version-controlled project
    "
    "}}}
    " I'm not satisfied with the labels!{{{
    "
    " Have a look at this for more inspiration:
    "
    " https://github.com/tpope/vim-flagship/issues/2#issuecomment-113824638
    "}}}
    " `b:root_dir` is set by `vim-cwd`
    if a:n == a:curtab || getbufvar(bufnr, 'root_dir', '') isnot# ''
        let cwd = getcwd(winnr, a:n)
        let cwd = pathshorten(substitute(cwd, '^\V'..escape($HOME, '\')..'/', '', ''))
        " append a slash to avoid confusion with a buffer name
        if cwd !~# '/' | let cwd ..= '/' | endif
        let label = cwd
    " otherwise, just display the name of the focused buffer
    else
        let label = fnamemodify(bufname, ':t')
    endif
    if a:n != a:curtab | return label | endif

    " Format the label so that it never exceeds `x` characters, and is centered.{{{
    "
    " This  is useful  to prevent  the tabline  from "dancing"  when we  focus a
    " different window in the same tab page.
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
    " Anyway, we will rarely work on files or projects with multibyte characters
    " in their names...
    "}}}
    let label = label[: s:TABLABEL_MAXSIZE - 1]
    let len = len(label)
    " `+4` to take into account a flag such as `[xy]`
    let cnt = (s:TABLABEL_MAXSIZE - (len+4))/2
    return repeat(' ', cnt)..label..repeat(' ', cnt+len%2)
endfu

fu statusline#tabpagewinnr(tabnr) abort "{{{2
    " return the number of windows inside the tab page `a:tabnr`
    let last_winnr = tabpagewinnr(a:tabnr, '$')
    " We are not interested in the number of windows inside:{{{
    "
    "    - the current tab page
    "    - another tab page if it only contains 1 window
    "}}}
    return tabpagenr() == a:tabnr || last_winnr == 1 ? '' : '['..last_winnr..']'
endfu

fu statusline#tail_of_path() abort "{{{2
    let tail = fnamemodify(@%, ':t')

    return &bt is# 'terminal'
       \ ?     '[term]'
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
    if ! get(g:, 'my_fugitive_branch', 0)
        return ''
    endif
    return exists('*fugitive#statusline') ? fugitive#statusline() : ''
endfu
