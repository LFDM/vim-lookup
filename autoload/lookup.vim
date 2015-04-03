let s:defaults = {
          \'javascript': {
          \  'substitute': ['\(\<\u\l\+\|\l\+\)\(\u\)' ,'\l\1-\l\2'],
          \  'extension' : '.js',
          \  'callsign'  : '.',
          \  'func_def'  : [
          \     { 'lhs': 'function ', 'rhs': '' },
          \     { 'lhs': 'this\.', 'rhs': ' = function' }
          \  ]
          \},
          \'html' : {
          \  'substitute': ['\v(.*)', '\1-directive'],
          \  'extension' : '.js',
          \  'callsign'  : '.',
          \  'func_def'  : []
          \}
      \}

function! lookup#setup()
  let vars = [ 'substitute', 'extension', 'callsign', 'func_def' ]
  for var in vars
    call s:setVar(var)
  endfor
endfunction

function! lookup#goToFuncOrFile()
  if !s:hasConfigurationDefined()
    return
  endif

  let jumped = lookup#goToFunc()
  if jumped
    return 1
  else
    return lookup#goToFile()
  endif
endfunction

function! lookup#goToFile()
  if !s:hasConfigurationDefined()
    return
  endif
  let keyword_settings = &iskeyword
  let &iskeyword = keyword_settings . ',-'
  let jumped = s:goToFile(expand('<cword>'))
  let &iskeyword = keyword_settings
  return jumped
endfunction

function! lookup#goToFunc()
  if !s:hasConfigurationDefined()
    return
  endif

  let word = expand('<cword>')
  let pos = getpos('.')
  normal! b
  " If we were already at the start of the word, we've moved too far
  if expand('<cword>') != word
    normal! w
  endif
  " Check if we are at the beginning of the line
  if getpos('.')[2] != 1
    normal! h
    " Check if we are calling a function from another file
    if getline('.')[getpos('.')[2] - 1] == b:lookup_callsign
      normal! b
      " Restore the position so we can come back after we've left this file
      let file_name = expand('<cword>')
      call setpos('.', pos)
      try
        call s:goToFile(file_name)
        return s:goToFunc(word)
      endtry
    endif
  endif
  call setpos('.', pos)
  return  s:goToFunc(word)
endfunction

function! s:goToFile(word)
  let lhs = b:lookup_substitute[0]
  let rhs = b:lookup_substitute[1]
  let file_name = substitute(a:word, lhs ,rhs, 'g')
  if a:word != file_name
    let full_name = file_name . b:lookup_extension
    try
      exec "find **/" . full_name
      return 1
    catch
      echo "Lookup could not find a file named " . full_name
    endtry
  endif
endfunction

function! s:goToFunc(word)
  let pos = getpos('.')
  let jumped = 0
  for def in b:lookup_func_def
    if !jumped
      call search(def.lhs . a:word . def.rhs, 'w')
      " If cursor has not moved we are done
      if !(pos == getpos('.'))
        let jumped = 1
      endif
    endif
  endfor
  if jumped
    normal! zt
  else
    echo "Could not find a function named " . a:word
  endif
  return jumped
endfunction

function! s:getValue(key)
  if exists('g:lookup_customizations')
    let custom = s:lookup_key(g:lookup_customizations, a:key)
    if custom
      return custom
    endif
  endif

  return s:lookup_key(s:defaults, a:key)
endfunction

function! s:lookup_key(dict, key)
  if has_key(a:dict, &ft)
    let container = get(a:dict, &ft)
    if has_key(container, a:key)
      return get(container, a:key)
    endif
  endif
endfunction

function! s:setVar(key)
  call setbufvar(bufname('%'), 'lookup_' . a:key, s:getValue(a:key))
endfunction

function! s:hasConfigurationDefined()
  if (exists('g:lookup_customizations') && has_key(g:lookup_customizations, &ft)) || has_key(s:defaults, &ft)
    return 1
  endif
endfunction
