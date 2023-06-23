scriptencoding utf-8
let s:save_cpo = &cpoptions
set cpoptions&vim

let g:iced#debug = get(g:, 'iced#debug', v:false)

let g:iced#util#pumvisible_fn = get(g:, 'iced#util#pumvisible_fn', function('pumvisible'))

function! iced#util#wait(pred, timeout_ms) abort
  if a:timeout_ms == -1
    " wait forever
    while a:pred()
      sleep 1m
    endwhile

    return v:true
  else
    let t = 0
    while a:pred() && t < a:timeout_ms
      sleep 1m
      let t = t + 1
    endwhile

    return (t < a:timeout_ms)
  endif
endfunction

function! iced#util#escape(s) abort
  let s = a:s
  let s = substitute(s, '\\', '\\\\', 'g')
  let s = substitute(s, '"', '\\"', 'g')
  return s
endfunction

function! iced#util#unescape(s) abort
  let s = a:s
  let s = substitute(s, '\\"', '"', 'g')
  let s = substitute(s, '\\\\', '\\', 'g')
  return s
endfunction

function! iced#util#ensure_array(x) abort
  return (type(a:x) == v:t_list ? a:x : [a:x])
endfunction

function! iced#util#debug(title, x) abort
  if g:iced#debug
    echom printf('DEBUG %s: %s', a:title, a:x)
  endif
endfunction

function! s:__save_local_marks() abort
  let res = {}
  "" a-z
  let mark_exprs = map(range(0, 25), {_, v -> printf("'%s", nr2char(v + 97))})
  "" last selected range
  let mark_exprs += ["'<", "'>"]

  for mark_expr in mark_exprs
    let pos = getpos(mark_expr)
    if pos == [0, 0, 0, 0] | continue | endif
    let res[mark_expr] = pos
  endfor
  return res
endfunction

function! s:__restore_local_marks(saved_result) abort
  for mark_expr in keys(a:saved_result)
    call setpos(mark_expr, a:saved_result[mark_expr])
  endfor
endfunction

function! iced#util#save_context() abort
  return {
        \ 'reg': @@,
        \ 'bufnr': bufnr('%'),
        \ 'view': winsaveview(),
        \ 'marks': s:__save_local_marks(),
        \ }
endfunction

function! iced#util#restore_context(saved_context) abort
  silent exe printf('b %d', a:saved_context.bufnr)
  silent call winrestview(a:saved_context.view)
  call s:__restore_local_marks(a:saved_context.marks)
  let @@ = a:saved_context.reg
endfunction

function! iced#util#has_status(resp, status) abort
  for resp in iced#util#ensure_array(a:resp)
    for status in get(resp, 'status', [''])
      if status ==# a:status
        return v:true
      endif
    endfor
  endfor
  return v:false
endfunction

function! iced#util#char_repeat(n, c) abort
  let ret = ''
  if a:n > 0
    for _ in range(a:n) | let ret = ret . a:c | endfor
  endif
  return ret
endfunction

function! iced#util#add_indent(n, s) abort
  if a:n == 0 |  return a:s | endif
  let spc = iced#util#char_repeat(a:n, ' ')
  return substitute(a:s, '\r\?\n', "\n".spc, 'g')
endfunction

function! iced#util#del_indent(n, s) abort
  let spc = iced#util#char_repeat(a:n, ' ')
  return substitute(a:s, '\r\?\n'.spc, "\n", 'g')
endfunction

function! iced#util#char() abort
  return getline('.')[max([col('.')-1, 0])]
endfunction

function! iced#util#partition(arr, n, is_all) abort
  let result = []
  let tmp = []
  let i = 0
  for x in a:arr
    if i < a:n
      call add(tmp, x)
    else
      call add(result, copy(tmp))
      let tmp = [x]
      let i = 0
    endif
    let i = i + 1
  endfor

  if a:is_all || len(tmp) == a:n
    call add(result, copy(tmp))
  endif

  return result
endfunction

function! iced#util#assoc(dict, k, v) abort
  let d = copy(a:dict)
  let d[a:k] = a:v
  return d
endfunction

function! iced#util#save_var(v, filename) abort
  let serialized = string(a:v)
  call writefile([serialized], a:filename)
endfunction

function! iced#util#read_var(filename) abort
  let serialized = readfile(a:filename)[0]
  let result = ''
  silent exec printf('let result = %s', serialized)
  return result
endfunction

function! iced#util#shorten(msg, ...) abort
  let max_length = 0
  if exists('v:echospace')
    let max_length = v:echospace + ((&cmdheight - 1) * &columns)
  else
    let max_length = (&columns * &cmdheight) - 1
    " from experimenting: seems to use 12 characters
    if &showcmd
      let max_length -= 12
    endif

    " from experimenting
    if &laststatus != 2
      let max_length -= 25
    endif
  endif

  let max_length = min([max_length, get(a:, 1, max_length)])
  let msg = substitute(a:msg, '\r\?\n', ' ', 'g')
  return (max_length >= 3 && len(msg) > max_length)
        \ ? strpart(msg, 0, max_length - 3).'...'
        \ : msg
endfunction

function! iced#util#select_keys(d, ks) abort
  let ret = {}
  for k in a:ks
    if !has_key(a:d, k) | continue | endif
    let ret[k] = a:d[k]
  endfor
  return ret
endfunction

function! iced#util#normalize_path(path) abort
  let path = substitute(a:path, '^file:', '', '')
  " NOTE: jar:file:/path/to/jarfile.jar!/path/to/file.clj
  if stridx(path, 'jar:') == 0
    " cf. https://github.com/vim/vim/compare/v8.2.3605...v8.2.3606
    if has('patch-8.2.3606') || has('nvim')
      let path = substitute(path, '^jar:file:', 'zipfile://', '')
    else
      let path = substitute(path, '^jar:file:', 'zipfile:', '')
    endif

    let path = substitute(path, '!/', '::', '')
  endif
  return path
endfunction

function! iced#util#delete_color_code(s) abort
  return substitute(a:s, '\[[0-9;]*m', '', 'g')
endfunction

function! iced#util#list_to_dict(ls, key_fn, val_fn) abort
  let result = {}
  for x in a:ls
    let result[a:key_fn(x)] = a:val_fn(x)
  endfor
  return result
endfunction

function! iced#util#group_by(ls, key_fn) abort
  let result = {}
  for x in a:ls
    let key = a:key_fn(x)
    let grouped = get(result, key, [])
    let grouped += [x]
    let result[key] = grouped
  endfor

  return result
endfunction

function! iced#util#split_by_length(s, len) abort
  let s = a:s
  let res = []
  while ! empty(s)
    let res += [strpart(s, 0, a:len)]
    let s = strpart(s, a:len)
  endwhile

  return res
endfunction

function! iced#util#store_and_slide_registers(v) abort
  let @9 = @8
  let @8 = @7
  let @7 = @6
  let @6 = @5
  let @5 = @4
  let @4 = @3
  let @3 = @2
  let @2 = @1
  let @1 = a:v
endfunction

function! iced#util#add_curpos_to_jumplist() abort
  " :h jumplist
  " > You can explicitly add a jump by setting the ' mark with "m'".
  silent normal! m'
endfunction

function! iced#util#pumvisible() abort
  return g:iced#util#pumvisible_fn()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
