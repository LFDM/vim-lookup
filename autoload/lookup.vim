let s:defaults = {
          \'javascript': {
          \  'substitute': ['\(\<\u\l\+\|\l\+\)\(\u\)' ,'\l\1-\l\2'],
          \  'extension' : '.js',
          \  'callsign'  : '.',
          \  'func_def'  : [
          \     { 'lhs': 'function ', 'rhs': '' },
          \     { 'lhs': 'this\.', 'rhs': ' = function' }
          \  ]
          \}
      \}

function! lookup#setup()
  let vars = [ 'substitute', 'extension', 'callsign', 'func_def' ]
  for var in vars
    call s:setVar(var)
  endfor
endfunction

function! lookup#goToFile()
  if !s:hasConfigurationDefined()
    return
  endif
  call s:goToFile(expand('<cword>'))
endfunction

function! lookup#goToFunc()
  let word = expand('<cword>')
  let pos = getpos('.')
  normal! b
  " When we were at the start of the word already, we moved to far
  if expand('<cword>') != word
    normal! w
  endif
  " Check if we are at the beginning of the line
  if getpos('.')[2] != 1
    normal! h
    " Check if we are calling a function from another file
    if getline('.')[getpos('.')[2] - 1] == b:lookup_callsign
      normal! b
      " Restore the position so we can come back after we left this file
      let file_name = expand('<cword>')
      call setpos('.', pos)
      try
        call s:goToFile(file_name)
        call s:goToFunc(word)
        return
      endtry
    endif
  endif
  call setpos('.', pos)
  call s:goToFunc(word)
endfunction

function! s:goToFile(word)
  let lhs = b:lookup_substitute[0]
  let rhs = b:lookup_substitute[1]
  let file_name = substitute(a:word, lhs ,rhs, 'g')
  if a:word != file_name
    let full_name = file_name . b:lookup_extension
    try
      exec "find **/" . full_name
    catch
      echo "Lookup could not find a file named " . full_name
    endtry
  endif
endfunction

function! s:goToFunc(word)
  let pos = getpos('.')
  let def_found = 0
  for def in b:lookup_func_def
    if !def_found
      call search(def.lhs . a:word . def.rhs, 'w')
      " If cursor has not moved we are done
      if !(pos == getpos('.'))
        let def_found = 1
      endif
    endif
  endfor
  if def_found
    normal! zt
  else
    echo "Could not find a function named " . a:word
  endif
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
