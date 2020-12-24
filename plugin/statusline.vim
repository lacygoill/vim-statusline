vim9script

if exists('g:loaded_statusline')
    finish
endif
g:loaded_statusline = 1

# FAQ {{{1
# What's the meaning of ...?{{{2
# %<{{{3
#
# It means: "you can truncate what comes right after".
#
#     $ vim -Nu NONE +'set ls=2|set stl=abcdef%<ghijklmnopqrstuvwxyz' +'10vs'
#     abcdef<xyz~
#
# Notice how  the *start* of  the text `ghi...xyz`  has been truncated,  not the
# end.  This is why `<` was chosen for  the item `%<` (and not `>`), and this is
# why `<` is positioned *before* the truncated text.
#
# However, if  the text that  comes before  `%<` is too  long, Vim will  have to
# truncate it too:
#
#     $ vim -Nu NONE +'set ls=2 stl=abcdefghijklmn%<opqrstuvwxyz' +'10vs'
#     abcdefghi>~
#
# Notice  that  this time,  it's  the  *end* of  the  *previous*  text which  is
# truncated, and that `>` is positioned after it.
#
# To summarize:
# `%<` describes a point from which Vim can truncate the text if needed.
# It starts by truncating as much text as necessary right *after* the point.
# If that's not enough, it goes on by truncating the text right *before* the point.
#
#     very long %< text
#
# If  "very long  text" is  too long  for  the status  line, Vim  will start  by
# truncating the start of " text":
#
#     very long %< text
#                 ---->
#                 as much as necessary
#
# and if truncating all of " text"  is not enough, it will then truncate the end
# of "very long ":
#
#     very long %< text
#     <---------
#     as much as necessary
#
# ---
#
# If you omit `%<`,  Vim assumes it's at the start, and  truncates from the very
# beginning:
#
#     $ vim -Nu NONE +'set ls=2 stl=abcdefghijklmnopqrstuvwxyz' +'10vs'
#     <rstuvwxyz~
#
# ---
#
# To control truncations, you must use:
#
#    - `%<` outside `%{}`
#    - `.123` inside `%{}` (e.g. `%.123{...}`)
#
# Note that `.123` truncates the start of the text, just like `%<`.

# %(%) {{{3
#
# Useful to set the desired width / justification of a group of items.
#
# Example:
#
#      ┌ left justification
#      │ ┌ width of the group
#      │ │
#      │ │ ┌ various items inside the group (%l, %c, %V)
#      │ │ ├─────┐
#     %-15(%l,%c%V%)
#     │           ├┘
#     │           └ end of group
#     │
#     └ beginning of group
#       the percent is separated from the open parenthesis because of the width field
#
# For more info, `:h 'stl`:
#
#    > ( - Start of item group.  Can  be used for setting the width and alignment
#    >                           of a section.  Must be followed by %) somewhere.
#
#    > ) - End of item group.    No width fields allowed.

# -123  field {{{3

# Set the width of a field to 123 cells.
#
# Can be used (after the 1st percent sign) with all kinds of items:
#
#    - `%l`
#    - `%{...}`
#    - `%(...%)`
#
# Useful to append a space to an item, but only if it's not empty:
#
#     %-12item
#         ├──┘
#         └ suppose that the width of the item is 11
#
# The width  of the field  is one unit  greater than the one  of the item,  so a
# space will be added; and the left-justifcation  will cause it to appear at the
# end (instead of the beginning).

# .123  field {{{3
#
# Limit the width of an item to 123 cells:
#
#     %.123item
#
# Can be used (after the 1st percent sign) with all kinds of items:
#
#    - `%l`
#    - `%{...}`
#    - `%(...%)`
#
# Truncation occurs with:
#
#    - a '<' at the start for text items
#    - a '>' at the end for numeric items (only `maxwid - 2` digits are kept)
#      the number after '>' stands for how many digits are missing
#}}}2
# What's the difference between `g:statusline_winid` and `g:actual_curwin`?{{{2
#
# The former can be used in a `%!` expression, the latter inside a `%{}` item.

# How to make sure two consecutive flags A and B are visually well separated?{{{2
#
# If the length of A is fixed (e.g. 12), and A is not highlighted:
#
#     %-13{item}
#      ├─┘
#      └ make the length of the flag one cell longer than the text it displays
#        and left-align it
#
# You could also append a space manually:
#
#     '%{item} '
#             ^
#
# But the space would be displayed unconditionally which you probably don't want.
#
# ---
#
# If the length of A is fixed, and A *is* highlighted, don't try to append a
# space; it would get highlighted which would be ugly.
#
# ---
#
# If  the length  of A  can  vary, highlight  it  with a  HG different  than
# `StatusLine` so that it clearly stands out.

# What are the "buffer", "window", "tabpage" and "global" scopes?{{{2
#
# A flag may give an information about:
#
#    - a buffer; we say it's in the *buffer scope*
#    - a window; we say it's in the *window scope*
#    - all buffers in a tabpage; we say it's in the *tabpage scope*
#    - some setting which applies to all buffers/windows/tabpages; we say it's in the *global scope*
#
# By convention, we display a flag in:
#
#    - the buffer scope, on the left of the status line
#    - the window scope, on the right of the status line
#    - the tabpage scope, at the end of a tab label
#    - the global scope, on the right of the tab line
#
# That's more or less what `vim-flagship` does.
# This is a useful convention because it makes a flag give more information;
# its position tells us what is affected.

# How to set a flag in the tabpage scope?{{{2
#
# Like for any other scope:
#
#     au User MyFlags statusline#hoist('tabpage', '[on]')
#
# However, if your flag depends on the tab page in which it's displayed, you may
# need the special placeholder `{tabnr}`.  For example, to include the number of
# windows inside a tab page, you would write:
#
#     au User MyFlags statusline#hoist('tabpage', '[%{tabpagewinnr({tabnr}, "$")}]')
#                                                                  ^-----^
#
# If your expression  is too complex to  fit directly in the  function call, and
# you  need to  compute the  flag via  another function,  make sure  to pass  it
# `{tabnr}` as an argument:
#                                                       v-----v
#     au User MyFlags statusline#hoist('tabpage', 'Func({tabnr})')
#     def Func(tabnr): string
#              ^---^
#         # compute the flag using `tabnr` to refer to the tab page number
#                                   ^---^
#         return '...'
#     enddef

# What is a "volatile" flag?{{{2
#
# If a flag  A is on for  one minute, then off  for one minute, then  on for one
# minute etc. while a flag B is on  for five consecutive minutes, then A is more
# **volatile** than B.
#
# The more volatile a flag is, the more on the right of the buffer/tabpage scope
# –  or on  the left  of the  window/global scope  – it  should be,  so that  it
# disturbs the position of as fewer flags as possible.

# I have 2 flags A and B in the same scope.  I don't know which one should be displayed first!{{{2
#
# Ask yourself this: how frequently could I be in a situation where B is on,
# and the state of A changes (on → off, off → on)?
#
# If the answer is "often", then B should be displayed:
#
#    - before A if they are in the buffer/tabpage scope
#    - after A if they are in the tabpage/global scope
#
# The goal is to prevent as much  as possible that a recently displayed flag
# disturbs the positions of existing flags.
#
# ---
#
# Don't think about it too much.  Tweak the priorities by experimentation.
# If  the display  of  A often  disturbs  the position  of  B, increase  A's
# priority so that it's greater than B's priority.

# For the priorities, what type of numbers should I use?{{{2
#
# Follow this  useful convention: any  flag installed from this  file should
# have a priority which is a multiple of 10.
# For flags installed from third-party plugins, use priorities which are not
# multiples of 10.
#
# I have a flag checking whether the value of an option has been altered.{{{2
# It is still displayed even when I restore the original value of the option!{{{3
#
# For a comma-separated list of items, the order matters.
# Your new  value may contain  the same  items as the  original value, but  in a
# different order.
#
#    1. you should not restore the option manually;
#       your plugin/script  should do  it, and  it should  not use  a "relative"
#       assignment operator like `+=`, but an "absolute" one like `=`
#
#    2. if your plugin/script  fails to restore the option, and  you need to
#       quickly fix it, just reload your  buffer (for a buffer-local option) or
#       restart Vim (for a global option)
#
# You could try to make the flags insensitive  to the order of the items, but it
# would add some complexity for a too small benefit.
# If one day you try to make them insensitive, make sure our `:Vo` command still
# works as expected.
#}}}1

# Init {{{1

# no more than `x` characters in a tab label
const TABLABEL_MAXSIZE = 20

# no more than `x` tab labels on the right/left of the tab label currently focused
const MAX_TABLABELS = 1

# HG to use to highlight the flags in the tab line
const HG_TAL_FLAGS = '%#StatusLineTermNC#'

const SCOPES = ['global', 'tabpage', 'buffer', 'window']
var flags_db = {'global': [], 'tabpage': [], 'buffer': [], 'window': []}
var flags = {'global': '', 'tabpage': '', 'buffer': '', 'window': ''}

# Options {{{1

# always show the status line and the tab line
set ls=2 stal=2

# `vim-flagship` recommends to remove the `e` flag from 'guioptions', because it:
#    > disables the GUI tab line in favor of the plain text version
set guioptions-=e

set tabline=%!statusline#tabline()

set stl=%!statusline#main()

# Functions {{{1
fu statusline#hoist(scope, flag, priority = 0, source = '') abort "{{{2
    unlockvar! s:flags_db
    if index(s:SCOPES, a:scope) == -1
        throw '[statusline] "' .. a:scope .. '" is not a valid scope'
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
        \ 'priority': a:priority,
        \ 'source': a:source,
        \ }]
    lockvar! s:flags_db
endfu

fu s:BuildFlags() abort
    for scope in keys(s:flags)
        let s:flags[scope] = deepcopy(s:flags_db[scope])
            \ ->sort({a,b -> a.priority - b.priority})
        if scope is# 'global' || scope is# 'window'
            call reverse(s:flags[scope])
        endif
       let s:flags[scope] = map(s:flags[scope], {_, v -> v.flag})->join('')
    endfor
    lockvar! s:flags
endfu

# statusline {{{2
def statusline#main(): string
    if g:statusline_winid != win_getid()
        return ' %1*%{statusline#tail_of_path()}%* '
            .. '%='
            .. '%{&l:scb ? "[scb]" : ""}'
            .. '%{&l:diff ? "[diff]" : ""}'
            .. '%{&l:pvw ? "[pvw]" : ""}'
            .. (win_id2win(g:statusline_winid)->getwinvar('&pvw', 0) ? '%4p%% ' : '')
    else
        return flags.buffer
            .. '%='
            .. flags.window
    endif
enddef

def statusline#tabline(): string #{{{2
    var s = ''
    var curtab: number
    var lasttab: number
    [curtab, lasttab] = [tabpagenr(), tabpagenr('$')]

    # Shortest Distance From Ends
    var sdfe = min([curtab - 1, lasttab - curtab])
    # How did you get this expression?{{{
    #
    # We don't want to see a label for a tab page which is too far away:
    #
    #     if abs(curtab - a:n) > max_dist | return '' | endif
    #                            ^------^
    #
    # Now, suppose we  want to see 2 labels  on the left and right  of the label
    # currently focused, but not more:
    #
    #     if abs(curtab - a:n) > 2 | return '' | endif
    #                            ^
    #
    # If we're in the middle of a big enough tabline, it will look like this:
    #
    #       | | | a | a | A | a | a | | |
    #                 │   │
    #                 │   └ label currently focused
    #                 └ some label
    #
    # Problem:
    #
    # Suppose we focus the last but two tab page, the tabline becomes:
    #
    #     | | | a | a | A | a | a
    #
    # Now suppose we focus the last but one tab page, the tabline becomes:
    #
    #     | | | | a | a | A | a
    #
    # Notice how the tabline  only contains 4 named labels, while  it had 5 just
    # before.   We want  the tabline  to always  have the  same amount  of named
    # labels, here 5:
    #
    #     | | | a | a | a | A | a
    #           ^
    #           to get this one we need `max_dist = 3`
    #
    # It appears that focusing the last but  one tab page is a special case, for
    # which `max_dist` should be `3` and not `2`.
    # Similarly, when we focus  the last tab page, we need  `max_dist` to be `4`
    # and not `2`:
    #
    #     | | | a | a | a | a | A
    #           ^   ^
    #           to get those, we need `max_dist = 4`
    #
    # So, we need to add a number to `2`:
    #
    #    ┌──────────────────────────────────────────┬──────────┐
    #    │              where is focus              │ max_dist │
    #    ├──────────────────────────────────────────┼──────────┤
    #    │ not on last nor on last but one tab page │ 2 + 0    │
    #    ├──────────────────────────────────────────┼──────────┤
    #    │ on last but one tab page                 │ 2 + 1    │
    #    ├──────────────────────────────────────────┼──────────┤
    #    │ on last tab page                         │ 2 + 2    │
    #    └──────────────────────────────────────────┴──────────┘
    #
    # But what is the expression to get this number?
    # Answer:
    # We need to consider two cases depending on whether `lasttab - curtab >= 2`
    # is true or false.
    #
    # If it's true, it  means that we're not near enough the  end of the tabline
    # to worry; we are in the general case for which `max_dist = 2` is correct.
    #
    # If it's false, it means that we're too  close from the end, and we need to
    # increase `max_dist`.
    # By how much? The difference between the operands:
    #
    #     2 - (lasttab - curtab)
    #
    # The pseudo-code to get `max_dist` is thus:
    #
    #     if lasttab - curtab >= 2
    #         max_dist = 2
    #     else
    #         max_dist = 2 + (2 - (lasttab - curtab))
    #
    # Now we also need to handle the case where we're too close from the *start*
    # of the tabline:
    #
    #     if curtab - 1 >= 2
    #         max_dist = 2
    #     else
    #         max_dist = 2 + (2 - (curtab - 1))
    #
    # Finally, we have to merge the two snippets:
    #
    #     sdfe = min([curtab - 1, lasttab - curtab])
    #     if sdfe >= 2
    #         max_dist = 2
    #     else
    #         max_dist = 2 + (2 - sdfe)
    #
    # Which  can be generalized to  an arbitrary number of  labels, by replacing
    # `2` with a variable `x`:
    #
    #     sdfe = min([curtab - 1, lasttab - curtab])
    #     if sdfe >= x
    #         max_dist = x
    #     else
    #         max_dist = x + (x - sdfe)
    #}}}
    var max_dist = MAX_TABLABELS + (sdfe >= MAX_TABLABELS ? 0 : MAX_TABLABELS - sdfe)
    # Alternative:{{{
    # for 3 labels:{{{
    #
    #     var max_dist =
    #         index([1, lasttab], curtab) != -1 ? 1 + 1
    #         :                                   1 + 0
    #}}}
    # for 5 labels:{{{
    #
    #     var max_dist =
    #           index([1, lasttab], curtab) != -1 ? 2 + 2
    #         : index([2, lasttab-1], curtab) != -1 ? 2 + 1
    #         :                                       2 + 0
    #}}}
    # for 7 labels:{{{
    #
    #     var max_dist =
    #           index([1, lasttab], curtab) != -1 ? 3 + 3
    #         : index([2, lasttab-1], curtab) != -1 ? 3 + 2
    #         : index([3, lasttab-2], curtab) != -1 ? 3 + 1
    #         :                                       3 + 0
    #}}}
    #}}}

    for i in range(1, lasttab)
        # color the label  of the current tab page with  the HG `TabLineSel` the
        # others with `TabLine`
        s ..= i == curtab ? '%#TabLineSel#' : '%#TabLine#'

        # set the tab page nr (used by the mouse to recognize the tab page on which we click)
        # If you can't create enough tab pages because of `E541`,{{{
        #
        # you may want  to comment this line  to reduce the number  of `%` items
        # used in `'tal'` which will increase the limit.
        #}}}
        s ..= '%' .. i .. 'T'

        # set the label
        var label: string
        if abs(curtab - i) > max_dist
            label = string(i)
        else
            label = ' %{statusline#tabpage_label(' .. i .. ',' .. curtab .. ')} '
            var tab_flags = substitute(flags.tabpage, '\m\C{tabnr}', i, 'g')
            if tab_flags != ''
                label ..= HG_TAL_FLAGS
                    .. tab_flags
                    .. '%#TabLine#'
                    .. (i != curtab ? ' ' : '')
            endif
        endif

        s ..= label .. '│'
    endfor

    # color the rest of the line with `TabLineFill` (until the flags), and reset tab page nr (`%T`)
    s ..= '%#TabLineFill#%T'

    # append global flags on the right of the tab line
    s ..= '%=' .. HG_TAL_FLAGS .. flags.global

    # If you want to get a closing label, try this:{{{
    #
    #                        ┌ %X    = closing label
    #                        │ 999   = nr of the tab page to close when we click on the label
    #                        │         (big nr = last tab page currently opened)
    #                        │ close = text to display
    #                        ├────────┐
    #     s ..= '%=%#TabLine#%999Xclose'
    #            ├┘
    #            └ right-align next labels
    #}}}
    return s
enddef
# What does `statusline#tabline()` return ?{{{
#
# Suppose we have 3 tab pages, and the focus is currently in the 2nd one.
# The value of `'tal'` could be similar to this:
#
#     %#TabLine#%1T %{MyTabLabel(1)}
#     %#TabLineSel#%2T %{MyTabLabel(2)}
#     %#TabLine#%3T %{MyTabLabel(3)}
#     %#TabLineFill#%T%=%#TabLine#%999Xclose
#
# Rules:
#
# - any item must begin with `%`
# - an expression must be surrounded with `{}`
# - the HGs must be surrounded with `#`
# - we should only use one of the 3 following HGs, to highlight:
#
#    ┌─────────────────────────┬─────────────┐
#    │ the non-focused labels  │ TabLine     │
#    ├─────────────────────────┼─────────────┤
#    │ the focused label       │ TabLineSel  │
#    ├─────────────────────────┼─────────────┤
#    │ the rest of the tabline │ TabLineFill │
#    └─────────────────────────┴─────────────┘
#}}}

def statusline#tabpage_label(n: number, curtab: number): string #{{{2
    var winnr = tabpagewinnr(n)
    var bufnr = win_getid(winnr, n)->winbufnr()
    var bufname = bufname(bufnr)
    if bufname != ''
        bufname = fnamemodify(bufname, ':p')
    endif

    var label: string
    # don't display anything in the label of the current tab page if we focus a special buffer
    if n == curtab && &bt != ''
        label = ''
    # Display the cwd iff:{{{
    #
    #    - the buffer has a name
    #
    #    - the file is in a version-controlled project,
    #      or the label is for the current tab page
    #
    #      In the latter case, we don't care about the name of the current file:
    #
    #        - it's already in the status line
    #        - it's complete in the status line
    #}}}
    # `b:root_dir` is set by `vim-cwd`
    elseif bufname != '' && (n == curtab || getbufvar(bufnr, 'root_dir', '') != '')
        var cwd = getcwd(winnr, n)
            ->substitute('^\V' .. escape($HOME, '\') .. '/', '', '')
            ->pathshorten()
        # append a slash to avoid confusion with a buffer name
        if cwd !~ '/'
            cwd ..= '/'
        endif
        label = cwd
    # otherwise, just display the name of the focused buffer
    else
        label = fnamemodify(bufname, ':t')
    endif
    # I'm not satisfied with the labels!{{{
    #
    # Have a look at this for more inspiration:
    #
    # https://github.com/tpope/vim-flagship/issues/2#issuecomment-113824638
    #}}}

    # truncate the label so that it never exceeds our chosen maximum of characters
    # What about multibyte characters?{{{
    #
    # Yes, we should write sth like:
    #
    #     label = matchstr(label, repeat('.', '10'))
    #     len = strchars(label, 1)
    #
    # But I'm concerned about the impact on Vim's performance.
    # I don't know how often this function is evaluated.
    # Anyway, we will rarely work on files or projects with multibyte characters
    # in their names...
    #}}}
    label = label[: TABLABEL_MAXSIZE - 1]
    # Add padding whitespace around the current tab label.{{{
    #
    # This  is useful  to prevent  the tabline  from "dancing"  when we  focus a
    # different window in the same tab page.
    #}}}
    if n != curtab
        return label
    endif
    var len = strlen(label)
    var cnt = (TABLABEL_MAXSIZE - len) / 2
    return repeat(' ', cnt) .. label .. repeat(' ', cnt + len % 2)
enddef

def statusline#tabpagewinnr(tabnr: number): string #{{{2
    # return the number of windows inside the tab page `tabnr`
    var last_winnr = tabpagewinnr(tabnr, '$')
    # We are not interested in the number of windows inside:{{{
    #
    #    - the current tab page
    #    - another tab page if it only contains 1 window
    #}}}
    return tabpagenr() == tabnr || last_winnr == 1 ? '' : '[' .. last_winnr .. ']'
enddef

def statusline#tail_of_path(): string #{{{2
    var tail = fnamemodify(@%, ':t')->strtrans()

    return &bt == 'terminal'
        ?     '[term]'
        : tail == ''
        ?     (&bt == 'nofile' ? '[Scratch]' : '[No Name]')
        :     tail
enddef
# The following comment is kept for educational purpose, but no longer relevant.{{{
# It applied to a different expression than the one currently used.  Sth like:
#
#     return &bt isnot# 'terminal'
#         \ ? &ft isnot# 'dirvish'
#         \ ? &bt isnot# 'quickfix'
#         \ ? tail != ''
#         \ ?     tail
#         \ :     '[No Name]'
#         \ :     b:qf_is_loclist ? '[LL]' : '[QF]'
#         \ :     '[dirvish]'
#         \ :     '[term]'
#}}}
# How to read the returned expression:{{{
#
#    - pair the tests and the values as if they were an imbrication of parentheses
#
#      Example:
#
#         1st test = &bt isnot# 'terminal'
#         last value = [term]
#
#         2nd test = &filetype isnot# 'dirvish'
#         penultimate value = [dirvish]
#
#         ...
#
#     - when a test fails, the returned value is immediately known:
#       it's the one paired with the test
#
#     - when a test succeeds, the next test is evaluated:
#       all the previous ones are known to be true
#
#     - If all tests succeed, the value which is used is `tail`.
#       It's the only one which isn't paired with any test.
#       It means that it's used iff all the tests have NOT failed.
#       It's the default value used for a buffer without any peculiarity:
#       random type, random name
#}}}

def CheckOptionHasNotBeenAltered(longopt: string, shortopt: string, priority: number) #{{{2
    # save original value of option in a buffer-local variable
    if shortopt == 'isk'
        # Why don't you save the original value of `'isk'` in a help file?{{{
        #
        # Open a help file, then restart Vim.
        # Without this guard, the `[isk]` flag is wrongly displayed.
        #
        #     local:  iskeyword=!-~,^*,^|,^",192-255,-
        #             Last set from ~/.vim/plugged/vim-session/plugin/session.vim
        #
        #     original value: @,48-57,_,192-255,-
        #
        # ---
        #
        # You could use this guard:
        #
        #     if !(&ft == 'help' && exists('g:SessionLoad'))
        #
        # But there would  still be another issue.   Execute `:h|e|q|h`; the
        # `[isk]` flag is – again – wrongly displayed:
        #
        #     local:  iskeyword=!-~,^*,^|,^",192-255,-
        #             Last set from ~/.vim/plugged/vim-help/after/ftplugin/help.vim
        #
        #     original value: @,48-57,_,192-255,-
        #}}}
        #   Ok, but why is `'isk'` a special case?{{{
        #
        # When we source  a session, `'isk'` is one of the few  options which is not
        # properly restored in a help file.
        # See `s:restore_these()` in `~/.vim/plugged/vim-session/plugin/session.vim`.
        #
        # And out  of those, it's the  only one in  which we are interested  to know
        # whether a script has altered its value.
        #}}}
        au SaveOriginalOptions BufNewFile,BufReadPost,FileType * if &ft != 'help'
            \ |     b:orig_iskeyword = &l:isk
            \ |     b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') .. '|unlet! b:orig_iskeyword'
            \ | endif
    else
        # Why must I use the long name of an option in `b:orig_...`?{{{
        #
        # If you used the short name, `:Vo` would fail to display the original value
        # of an option which has been altered.
        #
        # ---
        #
        # When you use `:Vo`, you may provide the short name or the long name of an option.
        # To make the code simpler in `debug#verbose#option()`, we need to normalize
        # this name; we do so with this kind of expression:
        #
        #     :echo execute('set isk?')->matchstr('[a-z]\+')
        #     iskeyword~
        #
        # Because  of this  normalization, the  rest of  the function  refers to  an
        # option via its long name.
        # In  particular,   at  the  end,   the  function  inspects  the   value  of
        # `b:orig_longopt`; for  it to work, we  need to create variable  names with
        # long option names.
        #}}}
        exe printf('au SaveOriginalOptions BufNewFile,BufReadPost,FileType * '
            .. 'b:orig_%s = &l:%s'
            .. '|b:undo_ftplugin = get(b:, "undo_ftplugin", "exe") .. "|unlet! b:orig_%s"',
            longopt, longopt, longopt)
    endif
    # install a flag whose purpose is to warn us whenever the value of the option is altered
    exe printf('au User MyFlags statusline#hoist('
        .. '"buffer", ''%%2*%%{&l:%s != get(b:, "orig_%s", &l:%s) ? "[%s+]" : ""}'', %d)',
        shortopt, longopt, shortopt, shortopt, priority)
enddef
augroup SaveOriginalOptions | au!
augroup END
#}}}1
# Autocmds {{{1

augroup MyStatusline | au!

    # get flags (including the ones from third-party plugins)
    au VimEnter * if exists('#User#MyFlags')
        \ |     do <nomodeline> User MyFlags
        \ |     BuildFlags()
        \ | endif

    au User MyFlags statusline#hoist('global', '%{&dip =~# "iwhiteall" ? "[dip~iwa]" : ""}', 10)
    # Why an indicator for the 'paste' option?{{{
    #
    # This is  an option  which has  too many  effects; we  need to  be informed
    # immediately whenever it's set.
    #}}}
    # When should I highlight a flag with `User2`?{{{
    #
    # When there is  no chance in hell  you've *manually* set the  option with a
    # value you don't want.
    #
    # E.g., we never tweak `'ic'` manually and  we don't want it to be reset; so
    # if it *is* reset we should be informed that it's broken; it probably means
    # that some plugin is badly written or has a bug which sometimes prevents it
    # to restore the option value after a temporary reset.
    #
    # OTOH, we  may sometimes tweak `'ve'`  (e.g. with `cov` mapping),  so if it
    # doesn't have its original default  value, it doesn't necessarily mean that
    # something is wrong; and it doesn't warrant a special highlighting.
    #}}}
    au User MyFlags statusline#hoist('global', '%2*%{&paste ? "[paste]" : ""}', 20)
    # Why an indicator for the 'wrapscan' option?{{{
    #
    # You'll probably need  to temporarily reset it while  replaying a recursive
    # macro; otherwise, it could be stuck in an infinite loop.
    # We currently have a mapping to toggle  the option, but we need some visual
    # clue to check whether the option is indeed reset.
    #}}}
    au User MyFlags statusline#hoist('global', '%{!&ws ? "[nows]" : ""}', 30)

    # Do *not* try to add a flag for `'lazyredraw'`.{{{
    #
    # We tried in the past, but it was too tricky.
    #
    # For example, if you try:
    #
    #     au User MyFlags statusline#hoist('global', '%{!&lz ? "[nolz]" : ""}', 40)
    #
    # Then execute `:redrawt`: the `[nolz]` flag is displayed in the tab line.
    # I think that when `:redrawt` is run, Vim resets the option temporarily.
    # Anyway, because of this, the flag could also be displayed when our autocmd
    # running `:redrawt` is triggered.
    #
    # ---
    #
    # Besides, the `sa` operator  from `vim-sandwich` temporarily resets `'lz'`,
    # and causes the  tab line to be  redrawn (btw, this has nothing  to do with
    # our `:redrawt` which we run from an autocmd).
    # As  a result,  the  `[nolz]` flag  is  displayed  as long  as  we stay  in
    # operator-pending mode, which is distracting.
    # To fix this, we need `&&  state('o') == ''`.
    #}}}

    # the lower the priority, the closer to the left end of the status line the flag is
    # Why the arglist at the very start?{{{
    #
    # So that the index is always in the same position.
    # Otherwise, when you traverse the arglist, the index position changes every
    # time the length of the filename  also changes; this is jarring when you're
    # traversing fast and you're looking for a particular index.
    #}}}
    au User MyFlags statusline#hoist('buffer', '%a', 10)
    au User MyFlags statusline#hoist('buffer', ' %1*%{statusline#tail_of_path()}%* ', 20)
    au User MyFlags statusline#hoist('buffer', '%r', 30)
    # Why do you disable the git branch flag with `0 &&`?{{{
    #
    # We're always working on a master branch, so this flag is not useful at the moment.
    # When  we'll start  to  regularly  work on  different  branches  of a  same
    # project, then it will become useful, and you should get rid of `0 &&`.
    #}}}
    au User MyFlags statusline#hoist('buffer',
        \ '%{0 && exists("*FugitiveStatusline") ? FugitiveStatusline() : ""}', 40)
    au User MyFlags statusline#hoist('buffer',
        \ '%2*%{&mod && bufname("%") != "" && &bt !=# "terminal" ? "[+]" : ""}', 50)
    au User MyFlags statusline#hoist('buffer',
        \   '%{&bt !=# "terminal" || mode() ==# "t" ? ""'
        \ .. ' : bufnr("")->term_getstatus() ==# "finished" ? "[finished]" : "[n]"}', 60)
    # Warning: Use this function *only* for buffer-local options.
    CheckOptionHasNotBeenAltered('autoindent', 'ai', 70)
    CheckOptionHasNotBeenAltered('iskeyword', 'isk', 80)

    # the lower the priority, the closer to the right end of the status line the flag is
    au User MyFlags statusline#hoist('window', '%5p%% ', 10)
    au User MyFlags statusline#hoist('window', '%9(%.5l,%.3v%)', 20)
    au User MyFlags statusline#hoist('window', '%{&l:pvw ? "[pvw]" : ""}', 30)
    au User MyFlags statusline#hoist('window', '%{&l:diff ? "[diff]" : ""}', 40)
    au User MyFlags statusline#hoist('window', '%{&l:scb ? "[scb]" : ""}', 50)
    au User MyFlags statusline#hoist('window', '%{&l:spell ? "[spell]" : ""}', 60)

    # TODO: Add a tabpage flag to show whether the focused project is dirty?{{{
    #
    # I.e. the project contains non-commited changes.
    #
    # If you  try to implement this  flag, cache the  state of the project  in a
    # buffer variable.
    # But when  would we update  the cache?   Running an external  shell command
    # (here `git(1)`) is costly...
    #}}}
    au User MyFlags statusline#hoist('tabpage', '%{statusline#tabpagewinnr({tabnr})}', 10)

    # Purpose:{{{
    #
    # We use the tab  line to display some flags telling  us whether some global
    # options are set; among them is `'paste'`
    # But the  tab line is not  automatically redrawn when we  (re)set an option
    # (contrary to the status line).
    # We want  to be informed *as  soon* *as* `'paste'` (and  possibly others in
    # the future) is (re)set.
    #
    # ---
    #
    # We would not  need this autocmd if  the tab line was  redrawn whenever the
    # status line is; which has been discussed in the past:
    #
    #    > My suggestion  (if it  isn't too  expansive) was  to always  refresh the
    #    > tabline, if the statusline is also refreshed. That seems consistent.
    #
    # Source: https://github.com/vim/vim/issues/3770#issuecomment-451972003
    #
    # But it has not been implemented for various reasons:
    #
    #    > We  could  either also  update  the  tabline,  or add  a  :redrawtabline
    #    > command.   The last  would  be more  logical, since  it  depends on  the
    #    > 'tabline' option and has nothing to do with what's in 'statusline'.
    #
    # Source: https://github.com/vim/vim/issues/3770#issuecomment-452082906
    # See also: https://github.com/vim/vim/issues/3770#issuecomment-452095497
    #}}}
    # Why the timer?{{{
    #
    # To avoid a flag being temporarily displayed  in the tab line when we use a
    # custom command which temporarily resets a global option.
    # For example, that may happen with `m)` (`vim-breakdown`).
    #
    # The timer  *should* make sure that  the redrawing occurs *after*  a custom
    # command has finished being processed, and  that it has restored any option
    # which was temporarily reset.
    #}}}
    # A flag for one of these options is briefly displayed in the tab line when I use a custom mapping/command!{{{
    #
    # That should not happen thanks to the timer, but if for some reason it does
    # happen and  it comes  from one  of your plugin  which temporarily  sets an
    # option, try to prefix `:set` with `:noa`:
    #
    #     noa set ve=all
    #     ^-^
    #
    # ---
    #
    # As a last resort, consider asking the  tab line to be redrawn whenever the
    # status line is, or whenever a global option is (re)set.
    # Open a new github issue, or leave a comment on issue #3770.
    # Try to include a good and simple MWE to convince the devs that it would be
    #
    # Or ask for `state()` to report whether  a function is being processed or a
    # script is being sourced.
    # This way, we could write:
    #
    #     %{&ve is# "all" && state("f") == "" ? "[ve=all]" : ""}
    #                               │
    #                               └ indicate that Vim is busy processing a function
    #                                 or sourcing a script
    #
    # Open a new github issue, or leave a comment on issue #3770.
    # Try to include a good and simple MWE to convince the devs that it would be
    # a worthy change.
    #}}}
    au OptionSet diffopt,paste,wrapscan timer_start(0, {-> execute('redrawt')})

    au CmdWinEnter * &l:stl = ' %l'
augroup END

# Commands {{{1

com -bar -nargs=? -range=% -complete=custom,Complete StlFlags DisplayFlags(<q-args>)

def Complete(_a: any, _l: any, _p: any): string
    return join(SCOPES, "\n")
enddef

def DisplayFlags(ascope: string)
    var scopes = ascope == '' ? SCOPES : [ascope]
    var lines = []
    for scope in scopes
        # underline each `scope ...` line with a `---` line
        lines += ['', 'scope ' .. scope, substitute('scope ' .. scope, '.', '-', 'g'), '']
        lines += mapnew(flags_db[scope], {_, v -> substitute(
            v.flag,
            '\s\+$',
            '\=repeat("\u2588", submatch(0)->strlen())',
            ''
            ) .. "\x01" .. v.priority
        })
        # `substitute()` makes visible a trailing whitespace in a flag

        # Purpose:{{{
        #
        # If there is one flag, and only one flag in a given scope, the flags in
        # the subsequent scopes will not be formatted correctly.
        # This is because the ranges in  our next global commands work under the
        # assumption that a scope always contains several flags.
        #
        # To fix this issue, we temporarily add a dummy flag.
        #
        # ---
        #
        # Our  global  commands still  give  the  desired  result when  a  scope
        # contains no flag.
        #}}}
        if len(flags_db[scope]) == 1
            lines += ['dummy flag 123']
        endif
    endfor
    exe 'pedit ' .. tempname()
    wincmd P
    if !&pvw | return | endif
    setl bt=nofile nobl noswf nowrap
    append(0, lines)
    var range = ':/^---//\d\+$/ ; /\d\+$//^\s*$\|\%$/-'
    # align priorities in a column
    exe 'sil keepj keepp g/^---/' .. range .. '!column -t -s' .. "\x01"
    # for each scope, sort the flags according to their priority
    sil! keepj keepp g/^---/exe range .. 'sort /.\{-}\ze\d\+$/ n'
    #  │
    #  └ in case the scope does not contain any flag
    sil keepj keepp g/dummy flag 123/d _
    keepj :1d _
    # highlight flags installed from third-party plugins
    matchadd('DiffAdd', '.*[1-9]$', 0)
    sil! fold#adhoc#main()
    sil! toggle_settings#auto_open_fold(1)
    nmap <buffer><nowait> q <plug>(my_quit)
    nmap <buffer><nowait> <cr> <cmd>echo <sid>GetSourceFile()<cr>
    nmap <buffer><nowait> <c-w>F <cmd>call <sid>OpenSourceFile()<cr>
enddef

def GetSourceFile(): string
    var scope = search('^scope', 'bnW')
        ->getline()
        ->matchstr('^scope \zs\w\+')
    var priority_under_cursor = getline('.')->matchstr('\d\+$')->str2nr()
    var source = deepcopy(flags_db[scope])
        ->filter({_, v -> v.priority == priority_under_cursor})
        ->get(0, {})
        ->get('source', '')
    return source
enddef

def OpenSourceFile()
    var source = GetSourceFile()
    if empty(source)
        return
    endif
    var file: string
    var lnum: string
    [file, lnum] = matchlist(source, '\(.*\):\(\d\+\)')[1:2]
    exe 'sp +' .. lnum .. ' ' .. file
    norm! zv
enddef

