if exists('g:loaded_statusline')
    finish
endif
let g:loaded_statusline = 1

let s:MAX_LIST_SIZE = 999

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
" TODO: try to simplify the code, using the Vim patch 8.1.1372{{{
"
" https://github.com/vim/vim/commit/1c6fd1e100fd0457375642ec50d483bcc0f61bb2
"
" Wait for Nvim to merge the patch.
"
" The patch introduces the variables `g:statusline_winid` and `g:actual_curwin`.
" I'm not  sure how to use  them, but I think  that with them, we  wouldn't need
" autocmds to set a local 'stl' anymore.
" We could set a global 'stl', and  handle all cases (active vs inactive window)
" in the function.
"
"     let active = winid() == g:statusline_winid
"
" See: https://github.com/vim/vim/issues/4406
"}}}
" FIXME: The status line is sometimes wrongly noisy.{{{
"
" Press `gt` in this file to open the location window with all the todos.
" Press `C-w CR` to open an entry in a new split window.
" The statusline of the unfocused top window is noisy; it shouldn't.
"
" ---
"
"     $ vim -d ~/.bashrc ~/.zshrc
"
" Why is the statusline in the right window noisy?
" Focus it, then get  back to the first window: it gets quiet,  which is what we
" wanted right from the start.
"
" Same issue if we start Vim with `-O`.
"
" I think the  issue is that BufWinEnter  or WinEnter is probably  fired for all
" windows, which makes all windows receive a noisy statusline:
"
"     au BufWinEnter,WinEnter  *  setl stl=%!statusline#main(1)
"                                                            │
"                                                            └ has focus
"
" But WinLeave is not fired as we could expect:
"
"     au WinLeave              *  setl stl=%!statusline#main(0)
"
" So, the statuslines are not reset to be quiet.
"}}}

" Functions {{{1
fu statusline#fugitive() abort "{{{2
    if !get(g:, 'my_fugitive_branch', 0)
        return ''
    endif
    return exists('*fugitive#statusline') ? fugitive#statusline() : ''
endfu

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

fu statusline#main(has_focus) abort "{{{2
    if !a:has_focus
        " Do not use `%-16{...}` to distance the position in the quickfix list from the right border.{{{
        "
        " The additional spaces would be added  no matter what; i.e. even if the
        " buffer is not a quickfix buffer.
        " We want them only in a quickfix buffer.
        "}}}
        " Is there a more efficient way of getting the percentage through the file?{{{
        "
        " Not sure, but you could try  to use `g:actual_curbuf` to check whether
        " the buffer is displayed in a preview window.
        " If it is, you would return a string containing `%p`.
        " If it does not, you would return another string without `%p`.
        "
        "     return buffer_is_not_in_a_preview_window
        "         \ ? ...
        "         \ : ...
        "
        " `g:actual_curwin` or `g:statusline_winid` would be better (btw, what's
        " the difference between the two?), but Nvim doesn't support them atm.
        "}}}
        return ' %1*%{statusline#tail_of_path()}%* '
        \     ..'%-7{&l:diff ? "[Diff]" : ""}'
        \     ..'%w'
        \     ..'%='
        \     ..'%{&l:pvw ? float2nr(100.0 * line(".")/line("$")).."% " : ""}'
        \     ..'%{
        \           &bt is# "quickfix"
        \           ?     line(".").."/"..line("$")..repeat(" ", 16 - len(line(".").."/"..line("$")))
        \           :     ""
        \        }'
    endif

    " Why an indicator for the 'paste' option?{{{
    "
    " Atm there's  an issue in  Nvim, where 'paste' may  be wrongly set  when we
    " paste  some text  on the  command-line  with a  trailing literal  carriage
    " return.
    "
    " Anyway,  this is  an option  which has  too many  effects; we  need to  be
    " informed immediately whenever it's set.
    "}}}
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
    " The first syntax is better, because the space is appended on the condition
    " the item is not empty; the second syntax adds a space unconditionally.
    "}}}
    return &ft is# 'freekeys'
       \ ?     '%=%-5l'
       \ : &ft is# 'undotree'
       \ ?     "%=%{line('.')..'/'..line('$')..' '}"
       \ : &ft is# 'fex_tree'
       \ ?     ' '..(get(b:, 'fex_curdir', '') is# '/' ? '/' : fnamemodify(get(b:, 'fex_curdir', ''), ':t'))
       \          ..'%=%-8(%l,%c%) %p%% '
       \ : &bt is# 'quickfix'
       \ ? (get(w:, 'quickfix_title', '') =~# '\<TOC$'
       \     ?      ''
       \     :      (get(b:, 'qf_is_loclist', 0) ? '[LL] ': '[QF] '))
       \      .."%.80{exists('w:quickfix_title')? '  '.w:quickfix_title : ''}"
       \      .."%=    %-15(%l/%L%) "
       \
       \ :       '%{statusline#list_position()}'
       \       ..' %1*%{statusline#tail_of_path()}%* '
       \       ..'%-5r'
       \       ..'%w'
       \       ..'%2*%-8{&paste ? "[paste]" : ""}%*'
       \       ..'%-5{&ve is# "all" ? "[ve]" : ""}'
       \       ..'%-12{&dip =~# "iwhiteall" ? "[iwhiteall]" : ""}'
       "\ NAS = No Auto Save
       \       ..'%-6{!exists("#auto_save_and_read") && exists("g:autosave_on_startup") ? "[NAS]" : ""}'
       "\ AOF = Auto Open Fold
       \       ..'%-6{exists("b:auto_open_fold_mappings") ? "[AOF]" : ""}'
       \       ..'%-7{&l:diff ? "[Diff]" : ""}'
       \       ..'%-7{exists("*capslock#status") ? capslock#status() : ""}'
       \       ..'%2*%{&modified && bufname("%") != "" && &bt isnot# "terminal" ? "[+]" : ""}%*'
       \       ..'%='
       \       ..'%{statusline#fugitive()}  '
       \       ..'%-5{exists("*session#status")  ? session#status()  : ""}'
       \       ..'%-8(%.5l,%.3v%)'
       \       ..'%4p%% '
       " About the positions of the indicators.{{{
       "
       " Let the modified flag (`[+]`) at the end of the left part of the status line.
       "
       "     \       ..'%2*%{&modified && ... ? "[+]" : ""}%*'
       "
       " If you move  it before, then you'll need to append  a space to separate
       " the flag from the next one:
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
       " But  this means  that the  space will  be included  in the  status line
       " UNconditionally. As a  result, when the  buffer is not  modified, there
       " will be 2 spaces between the flags surrounding the missing `[+]`.
       "
       " ---
       "
       " We try to put all temporary indicators  on the left, where they are the
       " most visible, and all the "lasting" indicators on the right.
       "
       " For example, if you enable  the fugitive indicator, you'll probably let
       " it on for more than just a few seconds; so we put it on the right.
       " OTOH, if you toggle `'ve'`  which enables the virtualedit indicator, it
       " will probably be for just a few seconds; so we put it on the left.
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
       " Atm, `vim-fex` relies  on `vim-statusline` to correctly  display in the
       " status line, the name of the directory whose contents is being viewed.
       "
       " That is not good.
       " Our plugins should have as few dependencies as possible.
       " A `fex_tree` buffer should set its own status line.
       "
       " Make sure no other plugin relies on `vim-statusline` to set its status line.
       "}}}
endfu

" This function can be called when we enter a window, or when we leave one.

" Treat a qf buffer separately.{{{3
"
" For a qf buffer, the default local value of 'stl' can be found here:
"
"     $VIMRUNTIME/ftplugin/qf.vim
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
"     if !a:has_focus
"         return 1st_expr
"     endif
"
" ... you  must NOT assume  that this expression will  only be evaluated  in the
" window in  which the focus  was just before. It  will be evaluated  inside ALL
" windows which don't have the focus, every time you change the focused window.
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
"         return '...'.(&bt is# 'quickfix' ? '...' : '')    ✘
"     endif
"     return &bt is# 'quickfix'                         ✔
"     ?...
"     :...
"
"
"     if !has_focus
"         return '...%{&bt is# 'quickfix' ? "..." : ""}'    ✔
"     endif
"     return &bt is# 'quickfix'                         ✔
"     ?...
"     :...

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
"          ┌ left justification
"          │ ┌ width of the group
"          │ │
"          │ │ ┌ various items inside the group
"          │ │ ├─────┐
"         %-15(%l,%c%V%)
"         │           ├┘
"         │           └ end of group
"         │
"         └ beginning of group
"           the percent is separated from the open parenthesis because of the width field
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
"    - `%l`
"    - `%{...}`
"    - `%(...%)`
"
" Useful to prepend a space to an item, but only if it's not empty:
"
"     %-42item
"         ├──┘
"         └ suppose that the width of the item is 41
"
" The width  of the field  is one unit  greater than the one  of the item,  so a
" space will be added; and the left-justifcation  will cause it to appear at the
" end (instead of the beginning).

" .42  field {{{3

" Limit the width of an item to 42 cells:
"
"     %.42item
"
" Can be used (after the 1st percent sign) with all kinds of items:
"
"    - `%l`
"    - `%{...}`
"    - `%(...%)`
"
" Truncation occurs with:
"
"    - a '<' on the left for text items
"    - a '>' on the right for numeric items (only `maxwid - 2` digits are kept)
"      the number after '>' stands for how many digits are missing

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
" }}}3

fu statusline#tabline() abort "{{{2
    let s = ''
    for i in range(1, tabpagenr('$'))
        " color the label of the current tab page with the HG TabLineSel
        " the others with TabLine
        let s ..= i == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#'

        " set the tab page nr
        " used by the mouse to recognize the tab page on which we click
        let s ..= '%'..i..'T'

        " set the label by invoking another function `statusline#tabpage_label()`
        let s ..= ' %{statusline#tabpage_label('..i..')} │'
        "          │                                    ├┘{{{
        "          │                                    └ space and vertical line
        "          │                                      to separate the label from the next one
        "          │
        "          └ space to separate the label from the previous one
        "}}}
    endfor

    " color the rest of the line with TabLineFill and reset tab page nr
    let s ..= '%#TabLineFill#%T'

    " Commented because I don't need a closing label, I don't use the mouse.
    " Keep it for educational purpose.
    "
    " add a closing label
    "                        ┌ %X    = closing label
    "                        │ 999   = nr of the tab page to close when we click on the label
    "                        │         (big nr = last tab page currently opened)
    "                        │ close = text to display
    "                        ├────────┐
    " let s ..= '%=%#TabLine#%999Xclose'
    "            ├┘
    "            └ right-align next labels

    return s
endfu

" What does `statusline#tabline()` return ?{{{
"
" Suppose we have 3 tab pages, and the focus is currently in the 2nd one.
" The value of 'tal' could be similar to this:
"
"     %#TabLine#%1T %{MyTabLabel(1)}
"     %#TabLineSel#%2T %{MyTabLabel(2)}
"     %#TabLine#%3T %{MyTabLabel(3)}
"     %#TabLineFill#%T%=%#TabLine#%999Xclose
"
" Rules:
"
" - Any item must begin with `%`.
" - An expression must be surrounded with `{}`.
" - The HGs must be surrounded with `##`.
" - We should only use one of the 3 following HGs, to highlight:
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
       \ : empty(name)
       \ ?     '∅'
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
" > disables the GUI tab line in favor of the plain text version
set guioptions-=e


" 'tabline' controls the contents of the tabline (tab pages labels)
" only for terminal
"
" But,  since the  number  of tab  labels  may  vary, we  can't  set the  option
" directly, we need to build it inside a function, and use the returned value of
" the latter.
set tabline=%!statusline#tabline()


" TODO: Do we really need autocmds?{{{
"
" https://github.com/vim/vim/issues/4406#issuecomment-495496763
"
"     fun! SetupStl(nr)
"       return get(extend(w:, { "is_active": (winnr() == a:nr) }), "", "")
"     endf
"
"     fun! BuildStatusLine(nr)
"       return '%{SetupStl(' . a:nr . ')} %{w:["is_active"] ? "active" : "inactive"}'
"     endf
"
"     " winnr() here is always the number of the *active* window
"     set statusline=%!BuildStatusLine(winnr())
"}}}
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
    au WinEnter,BufWinEnter  tmuxprompt,websearch  let &l:stl = '%=%-13l'
augroup END

