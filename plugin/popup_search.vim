```vim
" ============================================================================
" File: popup_search.vim
" Description: Global Search with Popup API for Vim 8.2
" ============================================================================

if exists('g:loaded_popup_search') || !has('patch-8.2.0000')
    finish
endif
let g:loaded_popup_search = 1

" --- Configuration & State ---
if !exists('s:search_query') | let s:search_query = "" | endif
let s:search_winid = -1
let s:ignore_case = 1
let s:max_width = 110
let s:raw_results = [] 
let s:search_timer = -1
let s:cursor_idx = strchars(s:search_query) 

" --- Highlight Definitions ---
highlight default SearchMatch         ctermfg=Yellow cterm=bold guifg=Yellow gui=bold guibg=NONE
highlight default SearchPath          ctermfg=Cyan guifg=#00ffff
highlight default SearchSep           ctermfg=Gray guifg=#555555
highlight default ExplorerSearchQuery ctermfg=White cterm=bold guifg=White gui=bold guibg=NONE
highlight default ExplorerCursor      ctermbg=88 ctermfg=White guibg=#880000 guifg=White cterm=bold gui=bold
highlight default ExplorerPath        ctermfg=Cyan guifg=Cyan
highlight default ExplorerCounter     ctermfg=2 cterm=bold guifg=#00AA00 gui=bold
highlight default HelpHeader          ctermfg=Yellow cterm=bold guifg=#EBCB8B gui=bold
highlight default HelpKey             ctermfg=Cyan   cterm=bold guifg=#88C0D0 gui=bold
highlight default HelpDescription     ctermfg=White  guifg=#D8DEE9
highlight default HelpFooter          ctermfg=Gray   guifg=#666666

" Initialize Text Properties
function! s:InitProps()
    let l:props = [
        \ {'id': 'prop_cursor',  'hl': 'ExplorerCursor', 'prio': 100},
        \ {'id': 'prop_counter', 'hl': 'ExplorerCounter', 'prio': 90},
        \ {'id': 'prop_path',    'hl': 'ExplorerPath',    'prio': 90},
        \ {'id': 'prop_query',   'hl': 'ExplorerSearchQuery', 'prio': 80},
        \ {'id': 'prop_h_head',  'hl': 'HelpHeader',      'prio': 80},
        \ {'id': 'prop_h_key',   'hl': 'HelpKey',         'prio': 80},
        \ {'id': 'prop_h_desc',  'hl': 'HelpDescription', 'prio': 80},
        \ {'id': 'prop_h_foot',  'hl': 'HelpFooter',      'prio': 80}
    \ ]
    for p in l:props
        if empty(prop_type_get(p.id))
            call prop_type_add(p.id, {'highlight': p.hl, 'priority': p.prio})
        endif
    endfor
endfunction
call s:InitProps()

function! s:ShowHelp()
    let l:help_content = [
        \ ' GLOBAL SEARCH SHORTCUTS ',
        \ ' ────────────────────────────────────────────────────────────── ',
        \ ' ',
        \ ' NAVIGATION ',
        \ '   Arrows / C-n / C-p      Move selection in results list ',
        \ '   Left / Right            Move cursor inside search text ',
        \ '   Home / End              Jump to start/end of search text ',
        \ ' ',
        \ ' ACTIONS ',
        \ '   Enter                   Open selected file at line ',
        \ '   Ctrl-s                  Toggle Case Sensitivity (Ignore/Match) ',
        \ '   Ctrl-u                  Clear entire search query ',
        \ '   Backspace / Del         Delete characters ',
        \ ' ',
        \ ' SYSTEM ',
        \ '   ?                       Show this help menu ',
        \ '   Esc                     Close search window ',
        \ ' ',
        \ ' ────────────────────────────────────────────────────────────── ',
        \ ' [ Press any key to return to search ] '
        \ ]
    let l:help_winid = popup_create(l:help_content, {
        \ 'title': ' Help ', 'border': [1,1,1,1], 'pos': 'center', 'padding': [1,4,1,4],
        \ 'minwidth': 75, 'filter': 'popup_filter_menu', 'zindex': 300,
        \ })
    let l:buf = winbufnr(l:help_winid)
    call prop_add(1, 1, {'type': 'prop_h_head', 'length': 26, 'bufnr': l:buf})
    call prop_add(4, 1, {'type': 'prop_h_head', 'length': 12, 'bufnr': l:buf})
    call prop_add(9, 1, {'type': 'prop_h_head', 'length': 9,  'bufnr': l:buf})
    call prop_add(15, 1, {'type': 'prop_h_head', 'length': 8,  'bufnr': l:buf})
    let l:key_lines = [5, 6, 7, 10, 11, 12, 13, 16, 17]
    for l:lnum in l:key_lines
        call prop_add(l:lnum, 4, {'type': 'prop_h_key', 'length': 23, 'bufnr': l:buf})
        call prop_add(l:lnum, 27, {'type': 'prop_h_desc', 'length': 40, 'bufnr': l:buf})
    endfor
    call prop_add(20, 1, {'type': 'prop_h_foot', 'length': 40, 'bufnr': l:buf})
endfunction

function! s:TriggerSearch()
    if s:search_timer != -1 | call timer_stop(s:search_timer) | endif
    let s:search_timer = timer_start(150, function('s:RunSearch'))
endfunction

function! s:RunSearch(...)
    let s:search_timer = -1
    if strchars(s:search_query) < 3
        let s:raw_results = []
        call s:RefreshDisplay()
        return
    endif
    let l:q = escape(s:search_query, '"\')
    if executable('rg')
        let l:cmd = printf('rg %s --vimgrep --smart-case --hidden --glob "!.git/*" "%s" . | head -n 101', (s:ignore_case ? "-i" : "--case-sensitive"), l:q)
    else
        let l:cmd = printf('grep -rIEn %s --exclude-dir=.git "%s" . | head -n 101', (s:ignore_case ? "-i" : ""), l:q)
    endif
    let s:raw_results = systemlist(l:cmd)
    call s:RefreshDisplay()
endfunction

function! s:RefreshDisplay()
    if s:search_winid == -1 | return | endif
    let l:buf = winbufnr(s:search_winid)
    let l:display_results = []
    let l:max_res_lines = 21
    let l:total_found = len(s:raw_results)
    let l:count_label = l:total_found > 100 ? "[100+ Matches]" : printf("[%d Matches]", l:total_found)
    if strchars(s:search_query) < 3
        let l:display_results = ["", "  Type at least 3 characters..."]
        let l:count_label = "[Waiting]"
    elseif empty(s:raw_results)
        let l:display_results = ["", "  No matches found."]
        let l:count_label = "[0 Matches]"
    else
        for l:line in s:raw_results[:l:max_res_lines-1]
            let l:parts = split(l:line, ':')
            if len(l:parts) >= 3
                let l:prefix = l:parts[0] . ':' . l:parts[1] . ':'
                let l:content = join(l:parts[2:], ':')
                let l:avail = s:max_width - strlen(l:prefix)
                if strlen(l:content) > l:avail | let l:content = strpart(l:content, 0, l:avail - 3) . "..." | endif
                call add(l:display_results, l:prefix . l:content)
            else
                call add(l:display_results, strpart(l:line, 0, s:max_width-3))
            endif
        endfor
    endif
    while len(l:display_results) < l:max_res_lines | call add(l:display_results, "") | endwhile
    let l:path_str = " Path: " . getcwd()
    let l:pad = repeat(" ", max([1, s:max_width - strlen(l:path_str) - strlen(l:count_label)]))
    let l:line1 = l:path_str . l:pad . l:count_label
    let l:sep = repeat('─', s:max_width)
    let l:prefix_search = ' [? Help] ' . (s:ignore_case ? "[Ignore]" : "[Match]") . ' Search: '
    let l:line25 = l:prefix_search . s:search_query . ' '
    call deletebufline(l:buf, 1, '$')
    call setbufline(l:buf, 1, [l:line1, l:sep] + l:display_results + [l:sep, l:line25])
    call prop_clear(1, 25, {'bufnr': l:buf})
    call prop_add(1, 1, {'type': 'prop_path', 'length': strlen(l:path_str), 'bufnr': l:buf})
    call prop_add(1, strlen(l:path_str . l:pad) + 1, {'type': 'prop_counter', 'length': strlen(l:count_label), 'bufnr': l:buf})
    let l:q_start = strlen(l:prefix_search) + 1
    call prop_add(25, l:q_start, {'type': 'prop_query', 'length': strlen(s:search_query), 'bufnr': l:buf})
    let l:cursor_byte_off = strlen(strcharpart(s:search_query, 0, s:cursor_idx))
    let l:char_at = strcharpart(s:search_query, s:cursor_idx, 1)
    let l:char_len = empty(l:char_at) ? 1 : strlen(l:char_at)
    call prop_add(25, l:q_start + l:cursor_byte_off, {'type': 'prop_cursor', 'length': l:char_len, 'bufnr': l:buf})
    call win_execute(s:search_winid, 'call clearmatches()')
    call win_execute(s:search_winid, 'call matchadd("SearchSep", "\%2l.*\\|\%24l.*", 10)')
    call win_execute(s:search_winid, 'call matchadd("SearchPath", "\%>2l\%<24l^[^:]\\+:[0-9]\\+:", 10)')
    if strchars(s:search_query) >= 3
        let l:pat = (s:ignore_case ? '\c' : '\C') . '\%>2l\%<24l\%(^[^:]\+:[0-9]\+:.*\)\@<=' . escape(s:search_query, '[]^$.*~\')
        call win_execute(s:search_winid, printf('call matchadd("SearchMatch", "%s", 11)', escape(l:pat, '"\')))
    endif
    let l:cur = getcurpos(s:search_winid)[1]
    if l:cur < 3 | call win_execute(s:search_winid, 'call cursor(3, 1)') | endif
    redraw
endfunction

function! s:SearchFilter(id, key)
    if a:key == "\<Esc>" | call popup_close(a:id, -1) | return 1
    elseif a:key == "\<CR>"
        let l:idx = getcurpos(a:id)[1]
        if l:idx >= 3 && l:idx <= 23
            let l:res_idx = l:idx - 3
            if l:res_idx < len(s:raw_results) | call popup_close(a:id, s:raw_results[l:res_idx]) | endif
        endif
        return 1
    elseif a:key == "?" | call s:ShowHelp() | return 1
    elseif a:key == "\<C-s>" | let s:ignore_case = !s:ignore_case | call s:TriggerSearch() | return 1
    elseif a:key == "\<Left>" | let s:cursor_idx = max([0, s:cursor_idx - 1]) | call s:RefreshDisplay() | return 1
    elseif a:key == "\<Right>" | let s:cursor_idx = min([strchars(s:search_query), s:cursor_idx + 1]) | call s:RefreshDisplay() | return 1
    elseif a:key == "\<BS>" || a:key == "\<C-h>"
        if s:cursor_idx > 0
            let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx - 1) . strcharpart(s:search_query, s:cursor_idx)
            let s:cursor_idx -= 1 | call s:TriggerSearch()
        endif
        return 1
    elseif a:key == "\<Del>"
        if s:cursor_idx < strchars(s:search_query)
            let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx) . strcharpart(s:search_query, s:cursor_idx + 1)
            call s:TriggerSearch()
        endif
        return 1
    elseif a:key == "\<C-u>" | let s:search_query = "" | let s:cursor_idx = 0 | call s:TriggerSearch() | return 1
    elseif a:key == "\<C-n>" || a:key == "\<C-p>" || a:key == "\<Up>" || a:key == "\<Down>"
        call popup_filter_menu(a:id, a:key)
        let l:cur = getcurpos(a:id)[1]
        if l:cur < 3 | call win_execute(a:id, 'call cursor(3, 1)') 
        elseif l:cur > 23 | call win_execute(a:id, 'call cursor(23, 1)') | endif
        return 1
    elseif a:key =~ '^\p$'
        let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx) . a:key . strcharpart(s:search_query, s:cursor_idx)
        let s:cursor_idx += 1 | call s:TriggerSearch() | return 1
    endif
    return 1 
endfunction

function! s:SearchCallback(id, result)
    let s:search_winid = -1
    if type(a:result) == v:t_string
        let l:parts = split(a:result, ':')
        execute 'edit ' . fnameescape(l:parts[0]) | execute l:parts[1] | normal! zz
    endif
endfunction

function! s:OpenGlobalSearch()
    let s:search_winid = popup_create([], {
        \ 'title': ' Global Search ', 'callback': function('s:SearchCallback'), 'filter': function('s:SearchFilter'),
        \ 'border': [1, 1, 1, 1], 'padding': [0, 1, 0, 1], 'minwidth': s:max_width, 'maxwidth': s:max_width,
        \ 'minheight': 25, 'maxheight': 25, 'cursorline': 1, 'mapping': 0,
        \ })
    let s:cursor_idx = strchars(s:search_query)
    if strchars(s:search_query) >= 3 | call s:RunSearch() | else | call s:RefreshDisplay() | endif
    call win_execute(s:search_winid, 'call cursor(3, 1)')
endfunction

command! GlobalSearch call s:OpenGlobalSearch()
nnoremap <leader>g :GlobalSearch<cr>