let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:setup() abort
  if !executable('bb')
    call iced#promise#sync(iced#system#get('installer').install, ['bb'], 10000)
  endif
endfunction

function! iced#script#empty_port(callback) abort
  call s:setup()
  let command = printf('bb --prn %s/clj/script/empty_port.clj', g:vim_iced_home)
  return iced#system#get('job_out').redir(command, a:callback)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
