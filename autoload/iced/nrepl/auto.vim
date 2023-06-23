let s:save_cpo = &cpoptions
set cpoptions&vim

let g:iced#nrepl#auto#does_switch_session = get(g:, 'iced#nrepl#auto#does_switch_session', v:false)
let g:iced#nrepl#auto#document_delay = get(g:, 'iced#nrepl#auto#document_delay', 500)
let s:leaving = v:false
let s:is_bufenter_enabled = v:false

function! s:auto_switching_session() abort
  if ! g:iced#nrepl#auto#does_switch_session | return | endif
  if iced#nrepl#check_session_validity(v:false) | return | endif
  if iced#nrepl#cljs#is_current_env_shadow_cljs() | return | endif

  let ext = expand('%:e')
  if ext ==# 'cljs' && iced#nrepl#cljs_session() !=# ''
    call iced#nrepl#change_current_session('cljs')
    call iced#hook#run('session_switched', {'session': 'cljs'})
  elseif ext ==# 'clj'
    call iced#nrepl#change_current_session('clj')
    call iced#hook#run('session_switched', {'session': 'clj'})
  endif
endfunction

function! iced#nrepl#auto#bufenter() abort
  if ! s:is_bufenter_enabled | return | endif

  if !iced#nrepl#is_connected() | return | endif
  call s:auto_switching_session()

  if !iced#nrepl#check_session_validity(v:false) | return | endif
  call iced#nrepl#ns#create()
endfunction

function! iced#nrepl#auto#bufread() abort
  if !iced#nrepl#is_connected() | return | endif

  if line('$') == 1 && empty(getline(1))
    call iced#skeleton#new()
  endif

  call s:auto_switching_session()
  if !iced#nrepl#check_session_validity(v:false) | return | endif

  call iced#nrepl#ns#create()
  call iced#format#set_indentexpr()
endfunction

function! iced#nrepl#auto#newfile() abort
  if !iced#nrepl#is_connected() | return | endif
  call iced#skeleton#new()
  call iced#format#set_indentexpr()
endfunction

function! iced#nrepl#auto#leave() abort
  let s:leaving = v:true
  return iced#repl#execute('disconnect')
endfunction

function! iced#nrepl#auto#enable_bufenter(bool) abort
  if type(a:bool) != v:t_bool | return | endif
  let s:is_bufenter_enabled = a:bool
endfunction

function! iced#nrepl#auto#cursor_moved() abort
  if ! iced#util#pumvisible()
    let timer = iced#system#get('timer')
    call timer.start_lazily(
          \ 'document_current_form',
          \ g:iced#nrepl#auto#document_delay,
          \ {-> iced#nrepl#document#current_form()})
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
