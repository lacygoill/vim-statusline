" TODO: {{{1

" Read the following links to improve the statusline.

" Blog post talking about status line customization:
"     http://www.blaenkdenum.com/posts/a-simpler-vim-statusline

" Vim Powerline-like status line without the need of any plugin:
"     https://gist.github.com/ericbn/f2956cd9ec7d6bff8940c2087247b132

" The last link uses the `%(%)` token; its meaning is explained in `:h 'stl`:
"
"     ( -   Start of item group.  Can be used for setting the width and
"           alignment of a section.  Must be followed by %) somewhere.
"     ) -   End of item group.  No width fields allowed.

" TODO:
" If possible, make the `%{statusline#list_position()}` item local to the current window.
" For inspiration, study `vim-flagship` first.

" Functions {{{1
fu! s:is_in_list_and_current() abort "{{{2
    return
    \      { 'qfl':
    \               { ->
    \                       [ s:cur_buf,         s:cur_line,       s:cur_col ]
    \                ==     [ s:cur_entry.bufnr, s:cur_entry.lnum, s:cur_entry.col ]
    \                ||
    \                       [ s:cur_buf,         s:cur_line       ]
    \                ==     [ s:cur_entry.bufnr, s:cur_entry.lnum ]
    \                &&     s:cur_entry.col == 0
    \                ||
    \                       s:cur_buf
    \                ==     s:cur_entry.bufnr
    \                &&     [ s:cur_entry.lnum, s:cur_entry.col ] == [ 0, 0]
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
    \                     [ s:cur_buf, s:cur_line, s:cur_col ]) != -1
    \               },
    \
    \        'arg': { -> index(map(range(s:argc), 'argv(v:val)'), s:bufname) != -1 }
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
    "             let Test = { -> foo + bar == 3 }
    "             let foo  = 1
    "             let bar  = 2
    "             return Test()
    "         endfu
    "         echo Func()
    "         → 1    ✘
    "
    "         fu! Func()
    "             let foo  = 1
    "             let Test = { -> foo + bar == 3 }
    "             let bar  = 2
    "             return Test()
    "         endfu
    "         echo Func()
    "         → E121    ✔}}}
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
            \?      {'qfl': 'C', 'arg': 'A'}[s:list.name]
            \
            \:   s:is_in_list_but_not_current()()
            \?      {'qfl': 'c', 'arg': 'a'}[s:list.name]
            \:      {'qfl': 'ȼ', 'arg': 'ā'}[s:list.name]
            \ )
            \ .'['.(idx + (s:list.name ==# 'arg' ? 1 : 0)).'/'.size.']'
    endfor

    return '[]'
endfu

fu! statusline#main(has_focus) abort "{{{2
    if !a:has_focus
        return ' %1*%{statusline#tail_of_path()}%* %w'
    endif
    return &ft ==# 'qf'
        \?     "%{get(b:, 'qf_is_loclist', 0) ? '[LL] ': '[QF] '}
        \%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}
        \ %=%-15(%l,%c%V%) %P"
        \:
        \       '%{statusline#list_position()}'
        \.      ' %1*%{statusline#tail_of_path()}%* '
        \.      '%-5r%-10w'
        \.      '%2*%{&modified && &buftype !=? "terminal" ? "[+]" : ""}%*'
        \.      '%='
        \.      '%-5{!empty(&ve) ? "[ve]" : ""}'
        \.      '%-7{exists("*capslock#status") ? capslock#status() : ""}'
        \.      '%-5{exists("*session#status")  ? session#status()  : ""}'
        \.      '%-8(%.5l,%.3v%)'
        \.      '%4p%% '
endfu

" This function can be called when we enter a window, or when we leave one.
"
" For a qf buffer, the default local value of 'stl' can be found here:
"         $VIMRUNTIME/ftplugin/qf.vim
"
" It's important  to treat it  separately, because  our default value  for 'stl'
" wouldn't give us much information in a qf window. In particular, we would miss
" its title.
"
" `main(1)` will be called only for the window to which we give the focus.
" But `main(0)` will be called for ANY window which doesn't have the focus.
" And `main(0)` will be called every time the statuslines must be redrawn,
" which happens every time we change the focus from a window to another.
" This means that when you write the 1st expression:
"
"         if !a:has_focus
"             return 1st_expr
"         endif
"
" … you must NOT assume that you're  leaving the window in which the focus was
" just before. You MUST assume that you're leaving ANY window which doesn't have
" the focus.
" This  means that,  in  this 1st  expression,  you can  NOT  reliably test  any
" buffer/window local variable.  You can in the 2nd expression: the one used for
" the focused window.

" About the modified flag: {{{3

"         %m    ✘
"
" Can't use this because we want the flag to be colored by HG `User1`.
"
"     (&modified ? '%2*%m%*' : '%m')    ✘
"
" Can't use this because `&modified` will be evaluated in the context
" of the current window and buffer. So the state of the focused window will be,
" wrongly, reflected in ALL statuslines.
"
"     %2*%{&modified ? "[+]" : ""}%*    ✔
"
" The solution is to use the `%{expr}` syntax, because the expression inside
" the curly braces is evaluated in the context of the window to which the statusline
" belongs.

" About the other items: "{{{3

"     ┌────────────────────────────────┬─────────────────────────────────────────────────────┐
"     │ %1*%t%*                        │ switch to HG User1, add filename, reset HG          │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %2*%{&modified ? "[+]" : ""}%* │ switch to HG User2, add flag modified [+], reset HG │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %r%w                           │ flags: read-only [RO], preview window [Preview]     │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %=                             │ right-align next items                              │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %{!empty(&ve) ? "[ve]" : ""}   │ flag for 'virtualedit'                              │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %l                             │ line nr                                             │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %v                             │ virtual column nr                                   │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %p%%                           │ percentage of read lines                            │
"     └────────────────────────────────┴─────────────────────────────────────────────────────┘

" About the `-{minwid}` field: {{{3

" When you want an item to be followed by a space, but only if it's not empty,
" write this:
"                 %-42item
"
" … the length of the item being 41. The width of the field will be one character
" longer than the item, so a space will be added; and the left-justifcation will
" cause it to appear at the end (instead of the beginning).

" About the `.{maxwid}` field: {{{3

" To prevent an item from taking too much space, you can limit its length like so:
"
"               %.42item
"
" Truncation occurs with:
"
"         • a '<' on the left for text items
"         • a '>' on the right for numeric items (only `maxwid - 2` digits are kept)
"           the number after '>' stands for how many digits are missing

fu! statusline#tail_of_path() abort "{{{2
    let tail = fnamemodify(expand('%:p'), ':t')

    return &buftype  !=# 'terminal'
        \? &filetype !=# 'dirvish'
        \? &filetype !=# 'qf'
        \? tail != ''
        \?     tail
        \:     '[No Name]'
        \:     b:qf_is_loclist ? '[LL]' : '[QF]'
        \:     '[dirvish]'
        \:     '[term]'
endfu

" How to read the returned expression:{{{
"
"     • pair the tests and the value as if they were an imbrication of parentheses
"
"     Example:
"             1st test    =    &buftype !=# 'terminal'
"             last value  =    [term]
"
"             2nd test           =    &buftype !=# 'dirvish'
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

augroup my_statusline
    au!
    au BufWinEnter,WinEnter   *         setl stl=%!statusline#main(1)
    au WinLeave               *         setl stl=%!statusline#main(0)
    au Filetype               dirvish   setl stl=%!statusline#main(0)

    " Alternative:
    " The last  autocmd is needed  for a dirvish  buffer, because no  WinEnter /
    " BufWinEnter event is fired right after its creation.
augroup END
