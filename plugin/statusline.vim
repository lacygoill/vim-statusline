" bufname('%') == argv(argidx())     →  test if current buffer is the current
"                                       argument in the arglist
"
" map(range(argc()), 'argv(v:val)')  →  arglist
"
" count(map(range(argc()), 'argv(v:val)'), bufname('%'))
"   →  test if the current buffer is somewhere in the arglist

    " '['.(argidx + 1).'/'.argc.']'



" NOTE:
" You may see the indicator `[ł]` in the statusline of a window where apparently
" there should be no location list. But remember, a window created with `:split`
" or `:tabnew` INHERITS the location list of its predecessor.
fu! Stl_list_position() abort
    if !get(g:, 'my_stl_list_position', 0)
        return ''
    endif

    " FIXME: At least ONE of the variables used by a lambda must be created BEFORE{{{
    " the lambda. Is it documented? I can't find anything in `:h closure`,
    " nor in `:h :func-closure` (nor on Vim's repo: `lambda E121`).
    "
    " So, here, we could move 2 out of the 3 following assignments after the lambda,
    " but at least 1 should stay before. I prefer to write the 3 before.
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
    "         → 1    ✔
    "
    "         fu! Func()
    "             let foo  = 1
    "             let Test = { -> foo + bar == 3 }
    "             let bar  = 2
    "             return Test()
    "         endfu
    "         echo Func()
    "         → E121    ✘}}}
    let [ s:cur_col, s:cur_line, s:cur_buf ] = [ col('.'),     line('.'), bufnr('%') ]
    let [ s:bufname, s:argidx, s:argc ]      = [ bufname('%'), argidx(),  argc() ]

    let s:lists = [ {'name': 'qfl', 'data': getqflist()},
                \   {'name': 'll',  'data': getloclist(0)},
                \   {'name': 'arg', 'data': map(range(argc()), 'argv(v:val)')} ]

    for s:list in s:lists
        if empty(s:list.data)
            continue
        endif

        let info = { 'qfl':  getqflist(   { 'idx': 1,         'size': 1      }),
                 \   'll' : getloclist(0, { 'idx': 1,         'size': 1      }),
                 \   'arg':               { 'idx':  argidx(), 'size': argc() },
                 \ }[s:list.name]

        if len(info) < 2 | continue | endif

        let [ idx, size ] = [ info.idx, info.size ]
        let s:cur_entry   = s:list.data[idx-1]

        return ( s:is_in_list_and_current()()
            \?      {'qfl': 'C', 'll': 'L', 'arg': 'A'}[s:list.name]
            \
            \:   s:is_in_list_but_not_current()()
            \?      {'qfl': 'c', 'll': 'l', 'arg': 'a'}[s:list.name]
            \:      {'qfl': 'ȼ', 'll': 'ł', 'arg': 'ā'}[s:list.name]
            \ )
            \ .'['.(idx + (s:list.name ==# 'arg' ? 1 : 0)).'/'.size.']'
    endfor

    return '[]'
endfu

fu! s:is_in_list_and_current() abort
    return
    \      { 'qfl':
    \               { ->
    \                       [ s:cur_buf,         s:cur_line,       s:cur_col ]
    \                ==     [ s:cur_entry.bufnr, s:cur_entry.lnum, s:cur_entry.col ]
    \                ||
    \                       [ s:cur_buf,         s:cur_line       ]
    \                ==     [ s:cur_entry.bufnr, s:cur_entry.lnum ]
    \                &&     s:cur_entry.col == 0
    \               },
    \
    \        'arg': { -> s:bufname ==# argv(s:argidx) }
    \      }[ s:list.name ==# 'll' ? 'qfl' : s:list.name ]
endfu

fu! s:is_in_list_but_not_current() abort
    return
    \      { 'qfl':
    \               { -> count(
    \                     map(deepcopy(s:list.data), '[ v:val.bufnr, v:val.lnum, v:val.col ]'),
    \                     [ s:cur_buf, s:cur_line, s:cur_col ])
    \               },
    \
    \        'arg': { -> count(map(range(s:argc), 'argv(v:val)'), s:bufname) }
    \      }[ s:list.name ==# 'll' ? 'qfl' : s:list.name ]
endfu



" NOTE:
" We want to have a modified flag:
"
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
"
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
"     │ %v                             │ virtual column -1nr                                 │
"     ├────────────────────────────────┼─────────────────────────────────────────────────────┤
"     │ %p%%                           │ percentage of read lines                            │
"     └────────────────────────────────┴─────────────────────────────────────────────────────┘

" When you want an item to be followed by a space, but only if it's not empty,
" write this:
"                 %-42item
"
" … the length of the item being 41. The width of the field will be one character
" longer than the item, so a space will be added; and the left-justifcation will
" cause it to appear at the end (instead of the beginning).

fu! My_status_line() abort
    return ' %1*%t%* '
       \.  '%2*%{&modified ? "[+]" : ""}%*'
       \.  '%-5r%-10w'
       \.  '%{exists("*Stl_list_position") ? Stl_list_position() : ""}'
       \.  '%='
       \.  '%-5{!empty(&ve) ? "[ve]" : ""}'
       \.  '%-7{exists("*CapsLock_stl") ? CapsLock_stl() : ""}'
       \.  '%-5{exists("*session#status") ? session#status() : ""}'
       \.  '%4.5l G'
       \.  '%4v |'
       \.  '%4p%% '
endfu

