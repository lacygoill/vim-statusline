if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

let s:MAX_LIST_SIZE = 999

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
fu! statusline#fugitive() abort "{{{2
    if !get(g:, 'my_fugitive_branch', 0)
        return ''
    endif
    return exists('*fugitive#statusline') ? fugitive#statusline() : ''
endfu

fu! s:is_in_list_and_current() abort "{{{2
    return
    \      { 'qfl':
    \               { ->
    \                        [s:cur_buf,         s:cur_line,       s:cur_col]
    \                    ==# [s:cur_entry.bufnr, s:cur_entry.lnum, s:cur_entry.col]
    \                ||
    \                        [s:cur_buf,         s:cur_line]
    \                    ==# [s:cur_entry.bufnr, s:cur_entry.lnum]
    \                    &&   s:cur_entry.col ==# 0
    \                ||
    \                         s:cur_buf
    \                    ==#  s:cur_entry.bufnr
    \                    && [s:cur_entry.lnum, s:cur_entry.col] ==# [0, 0]
    \               },
    \
    \        'arg': {-> s:bufname ==# argv(s:argidx)}
    \      }[s:list.name]
endfu

fu! s:is_in_list_but_not_current() abort "{{{2
    return
    \      {'qfl':
    \              {-> index(
    \                   map(deepcopy(s:list.entries), { i,v -> [v.bufnr, v.lnum, v.col]}),
    \                   [s:cur_buf, s:cur_line, s:cur_col]) >= 0
    \              },
    \
    \       'arg': {-> index(map(range(s:argc), { i,v -> argv(v) }), s:bufname) >= 0 }
    \      }[s:list.name]
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
    "             let l:Test = { -> foo + bar ==# 3 }
    "             let foo  = 1
    "             let bar  = 2
    "             return l:Test()
    "         endfu
    "         echo Func()
    "         E121~
    "
    "         fu! Func()
    "             let foo  = 1
    "             let l:Test = { -> foo + bar ==# 3 }
    "             let bar  = 2
    "             return l:Test()
    "         endfu
    "         echo Func()
    "         1~
    "         }}}
    let [s:cur_col, s:cur_line, s:cur_buf] = [col('.'),     line('.'), bufnr('%')]
    let [s:bufname, s:argidx, s:argc]      = [bufname('%'), argidx(),  argc()]

    if g:my_stl_list_position ==# 1 && get(getqflist({'size': 0}), 'size', 0) > s:MAX_LIST_SIZE
        return '[> '.s:MAX_LIST_SIZE.']'
    elseif g:my_stl_list_position ==# 2 && argc() > s:MAX_LIST_SIZE
        return '[> '.s:MAX_LIST_SIZE.']'
    endif

    let s:list = [
        \ {'name': 'qfl', 'entries': getqflist()},
        \ {'name': 'arg', 'entries': map(range(argc()), { i,v -> argv(v)})}
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
       \   .'['.(idx + (s:list.name is# 'arg' ? 1 : 0)).'/'.size.']'
endfu

" This function displays an item showing our position in the qfl or arglist.
"
" It only works when `g:my_stl_list_position` is set to 1 (which is not the case
" by default).   To toggle  the display,  install autocmds  which set  the value
" automatically when the qfl or arglist is populated.
"
" And/or use mappings, such as:
"
"         nno  <silent>  [oi  :let g:my_stl_list_position = 1<cr>
"         nno  <silent>  ]oi  :let g:my_stl_list_position = 0<cr>
"         nno  <silent>  coi  :let g:my_stl_list_position = !get(g:, 'my_stl_list_position', 0)<cr>

fu! statusline#main(has_focus) abort "{{{2
    if !a:has_focus
        " Do not  use `%-16{...}` to distance the position  in the quickfix from
        " the right border.
        " The additional spaces would be added  no matter what; i.e. even if the
        " buffer is not a quickfix buffer.
        " We want them only in a quickfix buffer.
        return ' %1*%{statusline#tail_of_path()}%* '
        \     .'%='
        \     .'%w'
        \     .'%{
        \           &bt is# "quickfix"
        \           ?     line(".")."/".line("$").repeat(" ", 16 - len(line(".")."/".line("$")))
        \           :     ""
        \        }'
        \     .'%{&l:diff ? "[Diff]" : ""}'
    endif

    " Why do you use a no-break space?{{{
    "
    "     \       .' %1*%{statusline#tail_of_path()}%* '
    "               ^
    "               no-break space
    "
    " I want a space to create some  distance between the file path and the left
    " edge of the screen.
    " But if  we use  one, in Neovim,  when the pager  is displayed  (like after
    " `:ls`), the  statusline is empty; it  seems the space is  repeated to fill
    " the whole line.
    "
    " MWE:
    "
    "     $ nvim -Nu NONE +'set stl=foobar'
    "     :ls
    "     no foobar~
    "
    "     $ nvim -Nu NONE +'set stl=\ foobar'
    "     :ls
    "     6 spaces~
    "
    " Using a no-break space prevents this issue.
    "
    " ---
    "
    " Note that we still  lose the contents of the statusline  when the pager is
    " displayed; but it's probably by design,  because Nvim seems to behave like
    " that since at least `v0.3.0`.
    "}}}
    return &ft is# 'freekeys'
       \ ?     '%=%-5l'
       \ : &ft is# 'fex_tree'
       \ ?     ' '.(get(b:, 'fex_curdir', '') is# '/' ? '/' : fnamemodify(get(b:, 'fex_curdir', ''), ':t'))
       \          .'%=%-8(%l,%c%) %p%% '
       \ : &bt is# 'quickfix'
       \ ? (get(w:, 'quickfix_title', '') =~# '\<TOC$'
       \ ?      ''
       \ :      (get(b:, 'qf_is_loclist', 0) ? '[LL] ': '[QF] '))
       \
       \      ."%.80{exists('w:quickfix_title')? '  '.w:quickfix_title : ''}"
       \      ."%=    %-15(%l/%L%) "
       \
       \ :      '%{statusline#list_position()}'
       \       .' %1*%{statusline#tail_of_path()}%* '
       \       .'%-5r'
       \       .'%2*%{&modified && bufname("%") != "" && &bt isnot# "terminal" ? "[+]" : ""}%*'
       \       .'%='
       \       .'%-5{&ve is# "all" ? "[ve]" : ""}'
       \       .'%-7{exists("*capslock#status") ? capslock#status() : ""}'
       \       .'%-5{exists("*session#status")  ? session#status()  : ""}'
       \       .'%-15{statusline#fugitive()}'
       \       .'%-8(%.5l,%.3v%)'
       \       .'%4p%% '
       \       .'%{&l:diff ? "[Diff]" : ""}'
endfu

" This function can be called when we enter a window, or when we leave one.

" Treat a qf buffer separately.{{{3
"
" For a qf buffer, the default local value of 'stl' can be found here:
"         $VIMRUNTIME/ftplugin/qf.vim
"
" It's important  to treat it  separately, because  our default value  for 'stl'
" wouldn't give us much information in a qf window. In particular, we would miss
" its title.

" Do NOT assume that the expression for non-focused windows will be evaluated only in the window you leave. {{{3
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
"         - you NEED a `%{}`              in the expression for the non-focused windows
"         - you CAN work without a `%{}`  in the expression for the     focused window
"
" This  explains  why you  can  test  `&ft` outside  a  `%{}`  item in  the  2nd
" expression, but not in the first:
"
"         if !has_focus
"             return '…'.(&bt is# 'quickfix' ? '…' : '')    ✘
"         endif
"         return &bt is# 'quickfix'                         ✔
"         ?…
"         :…
"
"
"         if !has_focus
"             return '…%{&bt is# 'quickfix' ? "…" : ""}'    ✔
"         endif
"         return &bt is# 'quickfix'                         ✔
"         ?…
"         :…

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

" %(%) {{{3
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

" -42  field {{{3

" Set the width of a field to 42 cells.
"
" Can be used (after the 1st percent sign) with all kinds of items:
"
"         - %l
"         - %{…}
"         - %(…%)
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

" .42  field {{{3

" Limit the width of an item to 42 cells:
"
"               %.42item
"
" Can be used (after the 1st percent sign) with all kinds of items:
"
"         - %l
"         - %{…}
"         - %(…%)
"
" Truncation occurs with:
"
"         - a '<' on the left for text items
"         - a '>' on the right for numeric items (only `maxwid - 2` digits are kept)
"           the number after '>' stands for how many digits are missing

" various items {{{3

"    ┌────────────────────────────────┬─────────────────────────────────────────────────────┐
"    │ %1*%t%*                        │ switch to HG User1, add filename, reset HG          │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %2*%{&modified ? "[+]" : ""}%* │ switch to HG User2, add flag modified [+], reset HG │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %r%w                           │ flags: read-only [RO], preview window [Preview]     │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %=                             │ right-align next items                              │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %{&ve is# "all" ? "[ve]" : ""} │ flag for 'virtualedit'                              │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %l                             │ line nr                                             │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %v                             │ virtual column nr                                   │
"    ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"    │ %p%%                           │ percentage of read lines                            │
"    └────────────────────────────────┴─────────────────────────────────────────────────────┘

fu! statusline#tabline() abort "{{{2
    let s = ''
    for i in range(1, tabpagenr('$'))
        " color the label of the current tab page with the HG TabLineSel
        " the others with TabLine
        let s .= i ==# tabpagenr() ? '%#TabLineSel#' : '%#TabLine#'

        " set the tab page nr
        " used by the mouse to recognize the tab page on which we click
        let s .= '%'.i.'T'

        " set the label by invoking another function `statusline#tabpage_label()`
        let s .= ' %{statusline#tabpage_label('.i.')} │'
        "         │                                  ├┘{{{
        "         │                                  └ space and vertical line
        "         │                                    to separate the label from the next one
        "         │
        "         └─ space to separate the label from the previous one
        "}}}
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
" - Any item must begin with `%`.
" - An expression must be surrounded with `{}`.
" - The HGs must be surrounded with `##`.
" - We should only use one of the 3 following HGs, to highlight:
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

    return getbufvar(bufnr, '&bt', '') is# 'terminal'
       \ ?     '[term]'
       \ : name[-1:] is# '/'
       \ ?     fnamemodify(name, ':h:t').'/'
       \ : getbufvar(bufnr, '&bt') is# 'quickfix'
       \ ?     getbufvar(bufnr, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
       \ : name =~# 'fex_tree$'
       \ ?     '┗ /'
       \ : name =~# 'fex_tree'
       \ ?     '┗ '.fnamemodify(name, ':t')
       \ : empty(name)
       \ ?     '∅'
       \ :     fnamemodify(name, ':t')
endfu

fu! statusline#tail_of_path() abort "{{{2
    let tail = fnamemodify(expand('%:p'), ':t')

    return &bt is# 'terminal'
       \ ?     '[term]'
       \ : &ft is# 'dirvish'
       \ ?     '[dirvish] '.expand('%:p')
       \ : &bt is# 'quickfix'
       \ ?     get(b:, 'qf_is_loclist', 0) ? '[LL]' : '[QF]'
       \ : tail is# 'fex_tree'
       \ ?     '/'
       \ :  expand('%:p') =~# '^fugitive://'
       \ ?     '[fgt]'
       \ : tail is# ''
       \ ?     '[No Name]'
       \ :     tail
endfu

" The following comment is kept for educational purpose, but no longer relevant.{{{
" It applied to a different expression than the one currently used. Sth like:
"
"         return &bt  isnot#  'terminal'
"            \ ? &ft  isnot#  'dirvish'
"            \ ? &bt  isnot#  'quickfix'
"            \ ? tail isnot# ''
"            \ ?     tail
"            \ :     '[No Name]'
"            \ :     b:qf_is_loclist ? '[LL]' : '[QF]'
"            \ :     '[dirvish]'
"            \ :     '[term]'
"}}}
" How to read the returned expression:{{{
"
"     - pair the tests and the values as if they were an imbrication of parentheses
"
"     Example:
"             1st test    =    &bt isnot# 'terminal'
"             last value  =    [term]
"
"             2nd test           =    &filetype isnot# 'dirvish'
"             penultimate value  =    [dirvish]
"
"             …
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
" }}}1
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

    au BufWinEnter,WinEnter  *  setl stl=%!statusline#main(1)
    au WinLeave              *  setl stl=%!statusline#main(0)

    " Why?{{{
    "
    " Needed  for some  special buffers,  because no  WinEnter /  BufWinEnter is
    " fired right after their creation.
    "}}}
    " But, isn't there a `(Buf)WinEnter` after populating the qfl and opening its window ?{{{
    "
    " Yes, but if  you close the window,  then later re-open it,  there'll be no
    " `(Buf)WinEnter`. OTOH, there will be a `FileType`.
    "}}}
    au Filetype  dirvish,man,qf  setl stl=%!statusline#main(1)
    au BufDelete UnicodeTable    setl stl=%!statusline#main(1)

    " show just the line number in a command-line window
    au CmdWinEnter  *  let &l:stl = '%=%-13l'
    " same thing in a websearch file
    " Why `WinEnter` *and* `BufWinEnter`?{{{
    "
    " `BufWinEnter` for when the buffer is displayed for the first time.
    " `WinEnter` for when we move to another window, then come back.
    "}}}
    " Why not `FileType`?{{{
    "
    " Because there's a `BufWinEnter` after `FileType`.
    " And we have an autocmd listening  to `BufWinEnter` which would set `'stl'`
    " with the value `%!statusline#main(1)`.
    "}}}
    au WinEnter,BufWinEnter  websearch  let &l:stl = '%=%-13l'
augroup END

