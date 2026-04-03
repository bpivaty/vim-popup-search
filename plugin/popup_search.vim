" plugin/sexy_search.vim
if exists('g:loaded_sexy_search') | finish | endif
let g:loaded_sexy_search = 1

" ============================================================================
" Global Search for Vim 8.2+ (Robust Cross-Platform Literal Search)
" ============================================================================

if v:version < 802
    echohl ErrorMsg | echo "Popup Search Error: Requires Vim 8.2+" | echohl None
    finish
endif

" --- State ---
let s:search_query = ""
let s:search_winid = -1
let s:ignore_case = 1
let s:raw_results = [] 
let s:search_timer = -1
let s:cursor_idx = 0 

let s:max_width  = get(g:, 'popup_search_width', 110)
let s:max_height = get(g:, 'popup_search_height', 25)
let s:path_width = get(g:, 'popup_search_path_width', 45)

" --- Highlighting Logic ---
function! s:ApplyHighlights()
    let l:m_fg = get(g:, 'popup_search_match_fg', 'Yellow')
    let l:p_fg = get(g:, 'popup_search_path_fg', 'Cyan')
    let l:s_fg = get(g:, 'popup_search_sep_fg', 'Gray')
    let l:q_fg = get(g:, 'popup_search_query_fg', 'White')
    let l:c_fg = get(g:, 'popup_search_cursor_fg', 'White')
    let l:h_fg = get(g:, 'popup_search_header_fg', 'Cyan')
    let l:n_fg = get(g:, 'popup_search_counter_fg', 'Green')
    let l:con_fg = get(g:, 'popup_search_content_fg', 'Green')
    let l:bg  = get(g:, 'popup_search_bg', '235')
    let l:gbg = get(g:, 'popup_search_gbg', '#262626')
    let l:c_bg  = get(g:, 'popup_search_cursor_bg', '88')
    let l:c_gbg = get(g:, 'popup_search_cursor_gbg', '#880000')

    execute printf('hi! ExplorerWin ctermbg=%s guibg=%s ctermfg=White guifg=White', l:bg, l:gbg)
    execute printf('hi! SearchMatch         ctermfg=%s guifg=%s cterm=bold gui=bold guibg=NONE', l:m_fg, l:m_fg)
    execute printf('hi! SearchPath          ctermfg=%s guifg=%s guibg=NONE', l:p_fg, l:p_fg)
    execute printf('hi! SearchSep           ctermfg=%s guifg=%s guibg=NONE', l:s_fg, l:s_fg)
    execute printf('hi! SearchContent       ctermfg=%s guifg=%s cterm=NONE gui=NONE guibg=NONE', l:con_fg, l:con_fg)
    execute printf('hi! ExplorerSearchQuery ctermfg=%s guifg=%s cterm=bold gui=bold guibg=NONE ctermbg=NONE', l:q_fg, l:q_fg)
    execute printf('hi! ExplorerPath        ctermfg=%s guifg=%s guibg=NONE', l:h_fg, l:h_fg)
    execute printf('hi! ExplorerCounter     ctermfg=%s guifg=%s cterm=bold gui=bold guibg=NONE', l:n_fg, l:n_fg)
    execute printf('hi! ExplorerCursor      ctermfg=%s guifg=%s ctermbg=%s guibg=%s cterm=bold gui=bold', l:c_fg, l:c_fg, l:c_bg, l:c_gbg)
    
    highlight default HelpHeader      ctermfg=Yellow cterm=bold guifg=#EBCB8B gui=bold
    highlight default HelpKey         ctermfg=Cyan   cterm=bold guifg=#88C0D0 gui=bold
    highlight default HelpDescription ctermfg=White  guifg=#D8DEE9
    highlight default HelpFooter      ctermfg=Gray   guifg=#666666
endfunction

function! s:InitProps()
    let l:props = [
        \ {'id': 'prop_match',   'hl': 'SearchMatch',         'prio': 100},
        \ {'id': 'prop_cursor',  'hl': 'ExplorerCursor',      'prio': 110},
        \ {'id': 'prop_path_hl', 'hl': 'SearchPath',          'prio': 90},
        \ {'id': 'prop_content', 'hl': 'SearchContent',       'prio': 85},
        \ {'id': 'prop_counter', 'hl': 'ExplorerCounter',     'prio': 90},
        \ {'id': 'prop_path',    'hl': 'ExplorerPath',        'prio': 90},
        \ {'id': 'prop_query',   'hl': 'ExplorerSearchQuery', 'prio': 80},
        \ {'id': 'prop_sep',     'hl': 'SearchSep',           'prio': 80},
        \ {'id': 'prop_h_head',  'hl': 'HelpHeader',          'prio': 80},
        \ {'id': 'prop_h_key',   'hl': 'HelpKey',             'prio': 80},
        \ {'id': 'prop_h_desc',  'hl': 'HelpDescription',     'prio': 80},
        \ {'id': 'prop_h_foot',  'hl': 'HelpFooter',          'prio': 80}
    \ ]
    for p in l:props
        if empty(prop_type_get(p.id)) 
            call prop_type_add(p.id, {'highlight': p.hl, 'priority': p.prio}) 
        endif
    endfor
endfunction

call s:ApplyHighlights()
call s:InitProps()

" --- Robust Help Screen ---

function! s:ShowHelp()
    let l:content = [
        \ {'text': ' GLOBAL SEARCH SHORTCUTS ', 'type': 'prop_h_head'},
        \ {'text': repeat('─', 65), 'type': 'prop_h_foot'},
        \ {'text': ' NAVIGATION ', 'type': 'prop_h_head'},
        \ {'text': '   Arrows / C-n / C-p      Move selection in results list ', 'key_len': 23},
        \ {'text': '   Left / Right            Move cursor inside search text ', 'key_len': 23},
        \ {'text': '   Home / End              Jump to start/end of search text ', 'key_len': 23},
        \ {'text': ' ACTIONS ', 'type': 'prop_h_head'},
        \ {'text': '   Enter                   Open selected file at line ', 'key_len': 23},
        \ {'text': '   Ctrl-s                  Toggle Case Sensitivity ', 'key_len': 23},
        \ {'text': '   Ctrl-u                  Clear entire search query ', 'key_len': 23},
        \ {'text': '   Backspace / Del         Delete characters ', 'key_len': 23},
        \ {'text': ' SYSTEM ', 'type': 'prop_h_head'},
        \ {'text': '   ?                       Show this help menu ', 'key_len': 23},
        \ {'text': '   Esc                     Close search window ', 'key_len': 23},
        \ {'text': repeat('─', 65), 'type': 'prop_h_foot'},
        \ {'text': ' [ Press any key to return to search ] ', 'type': 'prop_h_foot'}
        \ ]
    
    let l:lines = map(copy(l:content), 'printf("%-70s", v:val.text)')
    let l:help_winid = popup_create(l:lines, {
        \ 'title': ' Help ', 'border': [1,1,1,1], 'pos': 'center', 'padding': [1,4,1,4],
        \ 'minwidth': 70, 'filter': 'popup_filter_menu', 'zindex': 300, 'highlight': 'ExplorerWin'
        \ })

    let l:buf = winbufnr(l:help_winid)
    for i in range(len(l:content))
        let l:item = l:content[i]
        let l:lnum = i + 1
        if has_key(l:item, 'type')
            call prop_add(l:lnum, 1, {'type': l:item.type, 'length': strlen(l:item.text), 'bufnr': l:buf})
        elseif has_key(l:item, 'key_len')
            call prop_add(l:lnum, 4, {'type': 'prop_h_key', 'length': l:item.key_len, 'bufnr': l:buf})
            call prop_add(l:lnum, 4 + l:item.key_len, {'type': 'prop_h_desc', 'length': 40, 'bufnr': l:buf})
        endif
    endfor
endfunction

" --- Search Logic ---

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

    " Cross-platform null device
    let l:null = has('win32') ? 'nul' : '/dev/null'
    " shellescape handles quotes correctly for the current shell
    let l:q = shellescape(s:search_query)
    let l:excludes = get(g:, 'popup_search_exclude_dirs', ['.git'])
    let l:excl = ""

    if executable('rg')
        for l:d in l:excludes | let l:excl .= printf(' -g "!%s/*"', l:d) | endfor
        " Note: shellescape adds its own quotes, so we don't wrap %s in quotes here
        let l:cmd = printf('rg %s -F --vimgrep --smart-case --hidden %s %s .', (s:ignore_case ? "-i" : "--case-sensitive"), l:excl, l:q)
    else
        for l:d in l:excludes | let l:excl .= printf(' --exclude-dir=%s', l:d) | endfor
        let l:cmd = printf('grep -rIFEn %s %s %s .', (s:ignore_case ? "-i" : ""), l:excl, l:q)
    endif

    " Execute and suppress errors (like 'path not found' or 'permission denied')
    let s:raw_results = systemlist(l:cmd . ' 2>' . l:null)[:100]
    call s:RefreshDisplay()
endfunction

function! s:RefreshDisplay()
    if s:search_winid == -1 | return | endif
    let l:buf = winbufnr(s:search_winid)
    let l:max_res_lines = s:max_height - 4
    let l:total_found = len(s:raw_results)
    let l:count_label = l:total_found > 100 ? "[100+ Matches]" : printf("[%d Matches]", l:total_found)
    
    let l:display_results = []
    let l:col_data = [] 

    if strchars(s:search_query) < 3
        let l:display_results = ["", "  Type at least 3 characters..."]
    elseif empty(s:raw_results)
        let l:display_results = ["", "  No matches found."]
    else
        for l:line in s:raw_results[:l:max_res_lines-1]
            " Regex: Path:Line:OptionalCol:Content
            let l:parts = matchlist(l:line, '\v^(.{-}):(\d+):%(\d+:)?(.*)')
            
            if !empty(l:parts)
                let l:path = substitute(l:parts[1], '\\', '/', 'g')
                let l:lnum = l:parts[2]
                let l:content = trim(l:parts[3], " \t", 1)
                
                let l:path_with_line = l:path . ':' . l:lnum
                let l:path_fmt = (strlen(l:path_with_line) > s:path_width) ? '...' . strpart(l:path_with_line, strlen(l:path_with_line) - (s:path_width - 3)) : printf('%-' . s:path_width . 's', l:path_with_line)
                
                let l:spacer = "  "
                let l:avail = s:max_width - strlen(l:path_fmt . l:spacer)
                if strlen(l:content) > l:avail | let l:content = strpart(l:content, 0, l:avail - 3) . "..." | endif
                
                call add(l:display_results, l:path_fmt . l:spacer . l:content)
                call add(l:col_data, {'p_len': strlen(l:path_fmt), 's_len': strlen(l:spacer), 'raw_con': l:content})
            else
                call add(l:display_results, strpart(l:line, 0, s:max_width-3))
                call add(l:col_data, {'p_len': 0, 's_len': 0, 'raw_con': ''})
            endif
        endfor
    endif
    while len(l:display_results) < l:max_res_lines | call add(l:display_results, "") | endwhile

    let l:path_str = " Path: " . substitute(getcwd(), '\\', '/', 'g')
    let l:pad = repeat(" ", max([1, s:max_width - strlen(l:path_str) - strlen(l:count_label)]))
    let l:prefix_search = ' [? Help] ' . (s:ignore_case ? "[Ignore]" : "[Match]") . ' Search: '
    
    call deletebufline(l:buf, 1, '$')
    call setbufline(l:buf, 1, [l:path_str . l:pad . l:count_label, repeat('─', s:max_width)] + l:display_results + [repeat('─', s:max_width), l:prefix_search . s:search_query . ' '])

    call prop_clear(1, s:max_height, {'bufnr': l:buf})
    call prop_add(1, 1, {'type': 'prop_path', 'length': strlen(l:path_str), 'bufnr': l:buf})
    call prop_add(1, strlen(l:path_str . l:pad) + 1, {'type': 'prop_counter', 'length': strlen(l:count_label), 'bufnr': l:buf})
    call prop_add(2, 1, {'type': 'prop_sep', 'length': s:max_width, 'bufnr': l:buf})
    call prop_add(s:max_height - 1, 1, {'type': 'prop_sep', 'length': s:max_width, 'bufnr': l:buf})
    
    let l:q_start = strlen(l:prefix_search) + 1
    call prop_add(s:max_height, l:q_start, {'type': 'prop_query', 'length': strlen(s:search_query), 'bufnr': l:buf})
    let l:cursor_byte_off = strlen(strcharpart(s:search_query, 0, s:cursor_idx))
    let l:char_at = strcharpart(s:search_query, s:cursor_idx, 1)
    call prop_add(s:max_height, l:q_start + l:cursor_byte_off, {'type': 'prop_cursor', 'length': empty(l:char_at) ? 1 : strlen(l:char_at), 'bufnr': l:buf})

    if !empty(s:raw_results) && strchars(s:search_query) >= 3
        let l:lnum = 3
        for l:i in range(len(l:col_data))
            let l:c = l:col_data[l:i]
            if l:c.p_len > 0
                call prop_add(l:lnum, 1, {'type': 'prop_path_hl', 'length': l:c.p_len, 'bufnr': l:buf})
                let l:con_start = l:c.p_len + l:c.s_len + 1
                let l:line_text = l:display_results[l:i]
                let l:con_len = strlen(l:line_text) - l:con_start + 1
                if l:con_len > 0 | call prop_add(l:lnum, l:con_start, {'type': 'prop_content', 'length': l:con_len, 'bufnr': l:buf}) | endif
                
                let l:match_idx = s:ignore_case ? stridx(tolower(l:c.raw_con), tolower(s:search_query)) : stridx(l:c.raw_con, s:search_query)
                if l:match_idx != -1
                    call prop_add(l:lnum, l:con_start + l:match_idx, {'type': 'prop_match', 'length': strlen(s:search_query), 'bufnr': l:buf})
                endif
            endif
            let l:lnum += 1
        endfor
    endif
    let l:cur = getcurpos(s:search_winid)[1]
    if l:cur < 3 | call win_execute(s:search_winid, 'call cursor(3, 1)') | endif
    redraw
endfunction

" --- Interaction ---

function! s:SearchFilter(id, key)
    if a:key == "\<Esc>"
        call popup_close(a:id, -1)
    elseif a:key == "\<CR>"
        let l:idx = getcurpos(a:id)[1]
        let l:res_idx = l:idx - 3
        if l:res_idx >= 0 && l:res_idx < len(s:raw_results)
            call popup_close(a:id, s:raw_results[l:res_idx])
        endif
    elseif a:key == "?"
        call s:ShowHelp()
    elseif a:key == "\<C-s>"
        let s:ignore_case = !s:ignore_case
        call s:TriggerSearch()
    elseif a:key == "\<Left>"
        let s:cursor_idx = max([0, s:cursor_idx - 1])
        call s:RefreshDisplay()
    elseif a:key == "\<Right>"
        let s:cursor_idx = min([strchars(s:search_query), s:cursor_idx + 1])
        call s:RefreshDisplay()
    elseif a:key == "\<BS>" || a:key == "\<C-h>"
        if s:cursor_idx > 0
            let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx - 1) . strcharpart(s:search_query, s:cursor_idx)
            let s:cursor_idx -= 1
            call s:TriggerSearch()
        endif
    elseif a:key == "\<Del>"
        if s:cursor_idx < strchars(s:search_query)
            let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx) . strcharpart(s:search_query, s:cursor_idx + 1)
            call s:TriggerSearch()
        endif
    elseif a:key == "\<C-u>"
        let s:search_query = ""
        let s:cursor_idx = 0
        call s:TriggerSearch()
    elseif a:key == "\<C-n>" || a:key == "\<C-p>" || a:key == "\<Up>" || a:key == "\<Down>"
        call popup_filter_menu(a:id, a:key)
        let l:cur = getcurpos(a:id)[1]
        if l:cur < 3
            call win_execute(a:id, 'call cursor(3, 1)') 
        elseif l:cur > (s:max_height - 2)
            call win_execute(a:id, printf('call cursor(%d, 1)', s:max_height - 2))
        endif
    elseif a:key =~ '^\p$'
        let s:search_query = strcharpart(s:search_query, 0, s:cursor_idx) . a:key . strcharpart(s:search_query, s:cursor_idx)
        let s:cursor_idx += 1
        call s:TriggerSearch()
    endif
    return 1 
endfunction

function! s:SearchCallback(id, result)
    let s:search_winid = -1
    if type(a:result) == v:t_string
        let l:parts = matchlist(a:result, '\v^(.{-}):(\d+):')
        if !empty(l:parts)
            execute 'edit ' . fnameescape(l:parts[1])
            execute l:parts[2]
            normal! zz
        endif
    endif
endfunction

function! s:OpenGlobalSearch()
    call s:ApplyHighlights()
    let s:search_winid = popup_create([], {
        \ 'title': ' Global Search ', 'callback': function('s:SearchCallback'), 'filter': function('s:SearchFilter'),
        \ 'border': [1, 1, 1, 1], 'padding': [0, 1, 0, 1], 'minwidth': s:max_width, 'maxwidth': s:max_width,
        \ 'minheight': s:max_height, 'maxheight': s:max_height, 'cursorline': 1, 'mapping': 0, 'highlight': 'ExplorerWin'
        \ })
    let s:cursor_idx = strchars(s:search_query)
    if strchars(s:search_query) >= 3 | call s:RunSearch() | else | call s:RefreshDisplay() | endif
    call win_execute(s:search_winid, 'call cursor(3, 1)')
endfunction

command! GlobalSearch call s:OpenGlobalSearch()
nnoremap <leader>g :GlobalSearch<cr>
