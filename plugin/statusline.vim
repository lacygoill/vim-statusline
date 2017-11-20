if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

" TODO: {{{1

" Read the following links to improve the statusline.

" Blog post talking about status line customization:
"     http://www.blaenkdenum.com/posts/a-simpler-vim-statusline

" Vim Powerline-like status line without the need of any plugin:
"     https://gist.github.com/ericbn/f2956cd9ec7d6bff8940c2087247b132

" TODO:
" If possible, make the `%{statusline#list_position()}` item local to the current window.
" For inspiration, study `vim-flagship` first.

" Functions {{{1
fu! s:is_in_list_and_current() abort "{{{2
    return
    \      { 'qfl':
    \               { ->
    \                       [ s:cur_buf,         s:cur_line,       s:cur_col ]
    \                    == [ s:cur_entry.bufnr, s:cur_entry.lnum, s:cur_entry.col ]
    \                ||
    \                       [ s:cur_buf,         s:cur_line       ]
    \                    == [ s:cur_entry.bufnr, s:cur_entry.lnum ]
    \                    && s:cur_entry.col == 0
    \                ||
    \                       s:cur_buf
    \                    == s:cur_entry.bufnr
    \                    && [ s:cur_entry.lnum, s:cur_entry.col ] == [ 0, 0 ]
    \               },
    \
    \        'arg': { -> s:bufname ==# argv(s:argidx) }
    \      }[ s:list.name ]
endfu

fu! s:is_in_list_but_not_current() abort "{{{2
    return
    \      { 'qfl':
    \               { -> index(
    \                     map(deepcopy(s:list.data), '[ v:val.bufnr, v:val.lnum, v:val.col ]'),
    \                     [ s:cur_buf, s:cur_line, s:cur_col ]) >= 0
    \               },
    \
    \        'arg': { -> index(map(range(s:argc), 'argv(v:val)'), s:bufname) >= 0 }
    \      }[ s:list.name ]
endfu

fu! statusline#list_position() abort "{{{2
    if !get(g:, 'my_stl_list_position', 0)
        return ''
    endif

    " FIXME: At least ONE of the variables used by a lambda must be created BEFORE{{{
    " the lambda. Is it documented? I can't find anything in `:h closure`,
    " nor in `:h :func-closure` (nor on Vim's repo: `lambda E121`).
    "
    " I could understand the rule “all variables used by a lambda must be created
    " before the latter“. But, if some variables can be created after, why not all?
    "
    " Theory:
    " When one variable used  by a lambda is created before  the latter, it runs
    " in the context  of the function. When, all variables used  by a lambda are
    " created after the latter, it does NOT run in the context of the function.
    "
    " Anyway, here, we could move 2 out of the 3 following assignments after the
    " lambda, but at least 1 should stay before. I prefer to write the 3 before.
    "
    " Reproduce:
    "
    "         fu! Func()
    "             let l:Test = { -> foo + bar == 3 }
    "             let foo  = 1
    "             let bar  = 2
    "             return l:Test()
    "         endfu
    "         echo Func()
    "         → E121
    "
    "         fu! Func()
    "             let foo  = 1
    "             let l:Test = { -> foo + bar == 3 }
    "             let bar  = 2
    "             return l:Test()
    "         endfu
    "         echo Func()
    "         → 1
    "         }}}
    let [ s:cur_col, s:cur_line, s:cur_buf ] = [ col('.'),     line('.'), bufnr('%') ]
    let [ s:bufname, s:argidx, s:argc ]      = [ bufname('%'), argidx(),  argc() ]

    let lists = [ {'name': 'qfl', 'data': getqflist()},
              \   {'name': 'arg', 'data': map(range(argc()), 'argv(v:val)')} ]

    for s:list in lists
        if empty(s:list.data)
            continue
        endif

        let info = { 'qfl':  getqflist({ 'idx': 1,         'size': 1      }),
                 \   'arg':            { 'idx':  argidx(), 'size': argc() },
                 \ }[s:list.name]

        if len(info) < 2 | continue | endif

        let [ idx, size ] = [ info.idx, info.size ]
        let s:cur_entry   = s:list.data[idx-1]

        return ( s:is_in_list_and_current()()
        \?           {'qfl': 'C', 'arg': 'A'}[s:list.name]
        \:       s:is_in_list_but_not_current()()
        \?           {'qfl': 'c', 'arg': 'a'}[s:list.name]
        \:           {'qfl': 'ȼ', 'arg': 'ā'}[s:list.name]
        \      )
        \      .'['.(idx + (s:list.name ==# 'arg' ? 1 : 0)).'/'.size.']'
    endfor

    return '[]'
endfu

" This function displays an item showing our position in the qfl or arglist.
"
" It only works when `g:my_stl_list_position` is set to 1 (which is not the case
" by default).   To toggle  the display,  install autocmds  which set  the value
" automatically when the qfl or arglist is populated.
"
" And/or use mappings, such as:
"
"         nno <silent> [oi :let g:my_stl_list_position = 1<cr>
"         nno <silent> ]oi :let g:my_stl_list_position = 0<cr>
"         nno <silent> coi :let g:my_stl_list_position = !get(g:, 'my_stl_list_position', 0)<cr>

fu! statusline#main(has_focus) abort "{{{2
    if !a:has_focus
        return ' %1*%{statusline#tail_of_path()}%* %w%=%-22(%{
        \         &ft ==# "qf"
        \         ?     line(".")."/".line("$")
        \         :     ""}%)'
    endif
    return &l:buftype ==# 'quickfix'
    \?         "%{get(b:, 'qf_is_loclist', 0) ? '[LL] ': '[QF] '}
    \%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}
    \ %=%-15(%l/%L%) %4p%% "
    \
    \:          '%{statusline#list_position()}'
    \          .' %1*%{statusline#tail_of_path()}%* '
    \          .'%-5r%-10w'
    \          .'%2*%{&modified && &buftype !=? "terminal" ? "[+]" : ""}%*'
    \          .'%='
    \          .'%-5{&ve ==# "all" ? "[ve]" : ""}'
    \          .'%-7{exists("*capslock#status") ? capslock#status() : ""}'
    \          .'%-5{exists("*session#status")  ? session#status()  : ""}'
    \          .'%-8(%.5l,%.3v%)'
    \          .'%4p%% '
endfu

" This function can be called when we enter a window, or when we leave one.

" Treat a qf buffer separately.{{{
"
" For a qf buffer, the default local value of 'stl' can be found here:
"         $VIMRUNTIME/ftplugin/qf.vim
"
" It's important  to treat it  separately, because  our default value  for 'stl'
" wouldn't give us much information in a qf window. In particular, we would miss
" its title.
"}}}
" Do NOT assume that the expression for non-focused windows will be evaluated only in the window you leave. {{{
"
" `main(1)` will be evaluated only for the window to which we give the focus.
" But `main(0)` will be evaluated for ANY window which doesn't have the focus.
" And `main(0)` will be evaluated every time the statuslines must be redrawn,
" which happens every time we change the focus from a window to another.
" This means that when you write the 1st expression:
"
"         if !a:has_focus
"             return 1st_expr
"         endif
"
" … you  must NOT assume  that this expression will  only be evaluated  in the
" window in  which the focus  was just before. It  will be evaluated  inside ALL
" windows which don't have the focus, every time you change the focused window.
"
" This means that, if you want to reliably test a (buffer/window-)local variable:
"
"         • you NEED a `%{}`              in the expression for the non-focused windows
"         • you CAN work without a `%{}`  in the expression for the     focused window
"
" This  explains  why you  can  test  `&ft` outside  a  `%{}`  item in  the  2nd
" expression, but not in the first:
"
"         if !has_focus
"             return '…'.(&l:buftype ==# 'quickfix' ? '…' : '')    ✘
"         endif
"         return &l:buftype ==# 'quickfix'                         ✔
"         ?…
"         :…
"
"
"         if !has_focus
"             return '…%{&l:buftype ==# 'quickfix' ? "…" : ""}'    ✔
"         endif
"         return &l:buftype ==# 'quickfix'                         ✔
"         ?…
"         :…
"}}}
" %m {{{3

"     %m                                ✘
"
" Can't use this because we want the flag to be colored by HG `User2`.
"
"     (&modified ? '%2*%m%*' : '%m')    ✘
"
" Can't use  this because `&modified`  will be evaluated  in the context  of the
" window and buffer which has the focus. So the state of the focused window will
" be, wrongly, reflected in ALL statuslines.
"
"     %2*%{&modified ? "[+]" : ""}%*    ✔
"
" The solution is to use the `%{}` item, because the expression inside the curly
" braces  is evaluated  in the  context of  the window  to which  the statusline
" belongs.

" `%(%)` {{{3
"
" Useful to set the desired width / justification of a group of items.
"
" Example:
"
"          ┌─ left justification
"          │ ┌─ width of the group
"          │ │
"          │ │       ┌ various items inside the group
"          │ │ ┌─────┤
"         %-15(%l,%c%V%)
"         │           └┤
"         │            └ end of group
"         │
"         └─ beginning of group
"            the percent is separated from the open parenthesis because of the width field
"
" For more info, `:h 'stl`:
"
"     ( - Start of item group.  Can  be used for setting the width and alignment
"                               of a section.  Must be followed by %) somewhere.
"
"     ) - End of item group.    No width fields allowed.

" various items "{{{3

"     ┌────────────────────────────────┬─────────────────────────────────────────────────────┐
"     │ %1*%t%*                        │ switch to HG User1, add filename, reset HG          │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %2*%{&modified ? "[+]" : ""}%* │ switch to HG User2, add flag modified [+], reset HG │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %r%w                           │ flags: read-only [RO], preview window [Preview]     │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %=                             │ right-align next items                              │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %{&ve ==# "all" ? "[ve]" : ""} │ flag for 'virtualedit'                              │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %l                             │ line nr                                             │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %v                             │ virtual column nr                                   │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %p%%                           │ percentage of read lines                            │
"     └────────────────────────────────┴─────────────────────────────────────────────────────┘

" `-42` field {{{3

" Set the width of a field to 42 cells.
"
" Can be used (after the 1st percent sign) with all kinds of items:
"
"         • %l
"         • %{…}
"         • %(…%)
"
" Useful to prepend a space to an item, but only if it's not empty:
"
"                 %-42item
"                     └──┤
"                        └ suppose that the width of the item is 41
"
" The width  of the field  is one unit  greater than the one  of the item,  so a
" space will be added; and the left-justifcation  will cause it to appear at the
" end (instead of the beginning).

" `.42` field {{{3

" Limit the width of an item to 42 cells:
"
"               %.42item
"
" Can be used (after the 1st percent sign) with all kinds of items:
"
"         • %l
"         • %{…}
"         • %(…%)
"
" Truncation occurs with:
"
"         • a '<' on the left for text items
"         • a '>' on the right for numeric items (only `maxwid - 2` digits are kept)
"           the number after '>' stands for how many digits are missing

fu! statusline#tabline() abort "{{{2
    let s = ''
    for i in range(1, tabpagenr('$'))
        " color the label of the current tab page with the HG TabLineSel
        " the others with TabLine
        let s .= i == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#'

        " set the tab page nr
        " used by the mouse to recognize the tab page on which we click
        let s .= '%'.i.'T'

        " set the label by invoking another function `statusline#tabpage_label()`
        let s .= ' %{statusline#tabpage_label('.i.')} '
        "         │                                  │
        "         │                                  └─ space to separate the label from the next one
        "         └─ space to separate the label from the previous one
    endfor

    " color the rest of the line with TabLineFill and reset tab page nr
    let s .= '%#TabLineFill#%T'

    " Commented because I don't need a closing label, I don't use the mouse.
    " Keep it for educational purpose.
    "
    " add a closing label
    "                                ┌ %X    = closing label
    "                                │ 999   = nr of the tab page to close when we click on the label
    "                                │         (big nr = last tab page currently opened)
    "                                │ close = text to display
    "                       ┌────────┤
    " let s .= '%=%#TabLine#%999Xclose'
    "           └┤
    "            └ right-align next labels

    return s
endfu

" What does `statusline#tabline()` return ?{{{
"
" Suppose we have 3 tab pages, and the focus is currently in the 2nd one.
" The value of 'tal' could be similar to this:
"
"         %#TabLine#%1T %{MyTabLabel(1)}
"         %#TabLineSel#%2T %{MyTabLabel(2)}
"         %#TabLine#%3T %{MyTabLabel(3)}
"         %#TabLineFill#%T%=%#TabLine#%999Xclose
"
" Rules:
"
" • Any item must begin with `%`.
" • An expression must be surrounded with `{}`.
" • The HGs must be surrounded with `##`.
" • We should only use one of the 3 following HGs, to highlight:
"
"       ┌─────────────────────────┬─────────────┐
"       │ the non-focused labels  │ TabLine     │
"       ├─────────────────────────┼─────────────┤
"       │ the focused label       │ TabLineSel  │
"       ├─────────────────────────┼─────────────┤
"       │ the rest of the tabline │ TabLineFill │
"       └─────────────────────────┴─────────────┘
"}}}
fu! statusline#tabpage_label(n) abort "{{{2
    "                   ┌ I give you the nr of a tab page
    "             ┌─────┤
    let buflist = tabpagebuflist(a:n)
    "                    └─────┤
    "                          └ give me its buffer list:
    "                            for each window in the tab page, the function
    "                            adds the nr of the buffer that it displays
    "                            inside a list, and returns the final list
    "
    "                 ┌ I give you the nr of a tab page
    "           ┌─────┤
    let winnr = tabpagewinnr(a:n)
    "                  └───┤
    "                      └ give me the number of its focused window

    let bufnr = buflist[winnr - 1]

    "            ┌ I give you the nr of a buffer
    "          ┌─┤
    let name = bufname(bufnr)
    "             └──┤
    "                └ give me its name

    " Alternative to `get(b:, 'qf_is_loclist', 0)` :
    "
    "         get(get(getwininfo(win_getid(winnr, a:n)), 0, {}), 'loclist', 0)

    return getbufvar(bufnr, '&bt', '') ==# 'terminal'
    \?         '[term]'
    \:     name[-1:] ==# '/'
    \?         fnamemodify(name, ':h:t').'/'
    \:     getbufvar(bufnr, '&buftype') ==# 'quickfix'
    \?         getbufvar(bufnr, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
    \:     empty(name)
    \?         '∅'
    \:         fnamemodify(name, ':t')
endfu

fu! statusline#tail_of_path() abort "{{{2
    let tail = fnamemodify(expand('%:p'), ':t')

    return &buftype ==# 'terminal'
    \?         '[term]'
    \:     &filetype ==# 'dirvish'
    \?         '[dirvish]'
    \:     &l:buftype ==# 'quickfix'
    \?         get(b:, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
    \:     tail == ''
    \?         '[No Name]'
    \:         tail
endfu

" The following comment is kept for educational purpose, but no longer relevant.{{{
" It applied to a different expression than the one currently used. Sth like:
"
"         return &buftype   !=# 'terminal'
"         \?     &filetype  !=# 'dirvish'
"         \?     &l:buftype !=# 'quickfix'
"         \?     tail != ''
"         \?         tail
"         \:         '[No Name]'
"         \:         b:qf_is_loclist ? '[LL]' : '[QF]'
"         \:         '[dirvish]'
"         \:         '[term]'
"}}}
" How to read the returned expression:{{{
"
"     • pair the tests and the values as if they were an imbrication of parentheses
"
"     Example:
"             1st test    =    &buftype !=# 'terminal'
"             last value  =    [term]
"
"             2nd test           =    &filetype !=# 'dirvish'
"             penultimate value  =    [dirvish]
"
"             …
"
"     • when a test fails, the returned value is immediately known:
"       it's the one paired with the test
"
"     • when a test succeeds, the next test is evaluated:
"       all the previous ones are known to be true
"
"     • If all tests succeed, the value which is used is `tail`.
"       It's the only one which isn't paired with any test.
"       It means that it's used iff all the tests have NOT failed.
"       It's the default value used for a buffer without any peculiarity:
"       random type, random name
"}}}

" Options {{{1

" always enable the status line
set laststatus=2

" if you want to always enable the tabline
"
"         set showtabline=2
"
" Atm I don't do it, because I don't want it when there's only 1 tab page.


" `vim-flagship` recommends to remove the `e` flag from 'guioptions', because it:
"
"         “disables  the GUI  tab line  in favor  of the  plain text  version“
set guioptions-=e


" 'tabline' controls the contents of the tabline (tab pages labels)
" only for terminal
"
" But,  since the  number  of tab  labels  may  vary, we  can't  set the  option
" directly, we need to build it inside a function, and use the returned value of
" the latter.
set tabline=%!statusline#tabline()


augroup my_statusline
    au!

    au BufWinEnter,WinEnter   *         setl stl=%!statusline#main(1)
    au WinLeave               *         setl stl=%!statusline#main(0)

    " needed for  a man / dirvish  buffer, because no WinEnter  / BufWinEnter is
    " fired right after their creation
    au Filetype               man       setl stl=%!statusline#main(1)
    au Filetype               dirvish   setl stl=%!statusline#main(0)

    " show just the line number in a command line window
    au CmdWinEnter           *          let &l:stl = ' %l'
augroup END
