"==============================================================================
"    Copyright: Copyright (C) 2012 Stanislas Polu an other Contributors
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               dwm.vim is provided *as is* and comes with no warranty of
"               any kind, either expressed or implied. In no event will the
"               copyright holder be liable for any damages resulting from
"               the use of this software.
" Name Of File: dwm.vim
"  Description: Dynamic Window Manager behaviour for Vim
"   Maintainer: Stanislas Polu (polu.stanislas at gmail dot com)
" Last Changed: Tuesday, 23 August 2012
"      Version: See g:dwm_version for version number.
"        Usage: This file should reside in the plugin directory and be
"               automatically sourced.
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"==============================================================================

" Exit quickly if already running
if exists("g:dwm_version") || &diff || &cp
  finish
endif

let g:dwm_version = "0.1.2"

" Check for Vim version 700 or greater {{{1
if v:version < 700
  echo "Sorry, dwm.vim ".g:dwm_version."\nONLY runs with Vim 7.0 and greater."
  finish
endif

" We try to keep the following invariant:
" Any preview, quicklist, location list etc. open is open above/below the master pane.
" This function will close any preview, quicklist, location buffer.
" Also closes the undotree pane if undotree is installed.
" Call this function when the master window is about to be moved to the right,
" but bear in mind this may mess up the number of windows etc.
let s:reopen_quickfix = 0
function! DWM_Clean()
  " this id won't change even if we close windows
  let l:curwin = win_getid()

  " close undotree pane
  if exists(":UndotreeHide")
    :UndotreeHide
  endif
  " close preview window
  pclose
  " close quickfix
  let l:winn = winnr("$")
  cclose
  if winnr("$") < l:winn
    " we have actually closed it, remember to reopen it
    let s:reopen_quickfix = 1
  endif

  " now close all the location lists
  " when a window is closed, windo aborts
  " so we loop while at lest a window is closed
  let l:winn = winnr("$") + 1
  while winnr("$") < winn
    let l:winn = winnr("$")
    windo lclose
  endwhile

  " restore focus
  call win_gotoid(l:curwin)
endfunction

" Reopen the quickfix window after DWM_Clean.
" The location list which we closed is for a now unfocused window so we don't
" reopen it; and preview buffers cannot (?) be reopened.
" Call this when the focus is on the master pane. The quickfix window will be
" reopened below it.
function! DWM_Unclean()
  if s:reopen_quickfix
    " this id won't change even if we open windows
    let l:curwin = win_getid()
    below cwindow
    let s:reopen_quickfix = 0
    " restore focus
    call win_gotoid(l:curwin)
  endif
endfunction

" All layout transformations assume the layout contains one master pane on the
" left and an arbitrary number of stacked panes on the right
" +--------+--------+
" |        |   S1   |
" |        +--------+
" |   M    |   S3   |
" |        +--------+
" |        |   S3   |
" +--------+--------+

" Move the current master pane to the stack
function! DWM_Stack(clockwise)
  1wincmd w
  if a:clockwise
    " Move to the top of the stack
    wincmd K
  else
    " Move to the bottom of the stack
    wincmd J
  endif
  " At this point, the layout *should* be the following with the previous master
  " at the top.
  " +-----------------+
  " |        M        |
  " +-----------------+
  " |        S1       |
  " +-----------------+
  " |        S2       |
  " +-----------------+
  " |        S3       |
  " +-----------------+
endfunction

" Add a new buffer
function! DWM_New()
  call DWM_Clean()
  " Move current master pane to the stack
  call DWM_Stack(1)
  " Create a vertical split
  vert topleft new
  call DWM_ResizeMasterPaneWidth()

  call DWM_Unclean()
endfunction

" Move the current window to the master pane (the previous master window is
" added to the top of the stack). If current window is master already - switch
" to stack top
function! DWM_Focus()
  if winnr('$') == 1
    return
  endif

  call DWM_Clean()

  if winnr() == 1
    wincmd w
  endif

  let l:curwin = winnr()
  call DWM_Stack(1)
  exec l:curwin . "wincmd w"
  wincmd H
  call DWM_ResizeMasterPaneWidth()

  call DWM_Unclean()
endfunction

" Handler for BufWinEnter autocommand
" Recreate layout broken by new window
function! DWM_AutoEnter()
  if winnr('$') == 1
    return
  endif

  " Skip buffers without filetype
  if !len(&l:filetype)
    return
  endif

  " Skip quickfix buffers
  if &l:buftype == 'quickfix'
    return
  endif

  " Move new window to stack top
  wincmd K

  " Focus new window (twice :)
  call DWM_Focus()
  call DWM_Focus()
endfunction

" Close the current window
function! DWM_Close()
  if winnr() == 1
    " Close master panel.
    return 'close | wincmd H | call DWM_ResizeMasterPaneWidth()'
  else
    return 'close'
  end
endfunction

function! DWM_ResizeMasterPaneWidth()
  " Make all windows equally high and wide
  wincmd =

  " resize the master pane if user defined it
  if exists('g:dwm_master_pane_width')
    if type(g:dwm_master_pane_width) == type("")
      exec 'vertical resize ' . ((str2nr(g:dwm_master_pane_width)*&columns)/100)
    else
      exec 'vertical resize ' . g:dwm_master_pane_width
    endif
  endif
endfunction

function! DWM_GrowMaster()
  if winnr() == 1
    exec "vertical resize +1"
  else
    exec "vertical resize -1"
  endif
  if exists("g:dwm_master_pane_width") && g:dwm_master_pane_width
    let g:dwm_master_pane_width += 1
  else
    let g:dwm_master_pane_width = ((&columns)/2)+1
  endif
endfunction

function! DWM_ShrinkMaster()
  if winnr() == 1
    exec "vertical resize -1"
  else
    exec "vertical resize +1"
  endif
  if exists("g:dwm_master_pane_width") && g:dwm_master_pane_width
    let g:dwm_master_pane_width -= 1
  else
    let g:dwm_master_pane_width = ((&columns)/2)-1
  endif
endfunction

function! DWM_Rotate(clockwise)
  call DWM_Clean()
  call DWM_Stack(a:clockwise)
  if a:clockwise
    wincmd W
  else
    wincmd w
  endif
  wincmd H
  call DWM_ResizeMasterPaneWidth()
  call DWM_Unclean()
endfunction

nnoremap <silent> <Plug>DWMRotateCounterclockwise :call DWM_Rotate(0)<CR>
nnoremap <silent> <Plug>DWMRotateClockwise        :call DWM_Rotate(1)<CR>

nnoremap <silent> <Plug>DWMNew   :call DWM_New()<CR>
nnoremap <silent> <Plug>DWMClose :exec DWM_Close()<CR>
nnoremap <silent> <Plug>DWMFocus :call DWM_Focus()<CR>

nnoremap <silent> <Plug>DWMGrowMaster   :call DWM_GrowMaster()<CR>
nnoremap <silent> <Plug>DWMShrinkMaster :call DWM_ShrinkMaster()<CR>

if !exists('g:dwm_map_keys')
  let g:dwm_map_keys = 1
endif

if g:dwm_map_keys
  nnoremap <C-J> <C-W>w
  nnoremap <C-K> <C-W>W

  if !hasmapto('<Plug>DWMRotateCounterclockwise')
      nmap <C-,> <Plug>DWMRotateCounterclockwise
  endif
  if !hasmapto('<Plug>DWMRotateClockwise')
      nmap <C-.> <Plug>DWMRotateClockwise
  endif

  if !hasmapto('<Plug>DWMNew')
      nmap <C-N> <Plug>DWMNew
  endif
  if !hasmapto('<Plug>DWMClose')
      nmap <C-C> <Plug>DWMClose
  endif
  if !hasmapto('<Plug>DWMFocus')
      nmap <C-@> <Plug>DWMFocus
      nmap <C-Space> <Plug>DWMFocus
  endif

  if !hasmapto('<Plug>DWMGrowMaster')
      nmap <C-L> <Plug>DWMGrowMaster
  endif
  if !hasmapto('<Plug>DWMShrinkMaster')
      nmap <C-H> <Plug>DWMShrinkMaster
  endif
endif

if has('autocmd')
  function! DWM_EnableAutoManagement()
    augroup dwm
      au!
      au BufWinEnter * if &l:buflisted || &l:filetype == 'help' | call DWM_AutoEnter() | endif
    augroup end
  endfunction

  function! DWM_DisableAutoManagement()
    augroup dwm
      au!
    augroup end
  endfunction

  command DWMEnable call DWM_EnableAutoManagement()
  command DWMDisable call DWM_DisableAutoManagement()

  call DWM_EnableAutoManagement()
endif
