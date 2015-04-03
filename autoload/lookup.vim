let s:defaults = {
          \'javascript': {
          \  'substitute': ['\(\<\u\l\+\|\l\+\)\(\u\)' ,'\l\1-\l\2'],
          \  'extension' : '.js',
          \  'callsign'  : '.',
          \  'func_def'  : [
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
  call search('function ' . a:word, 'w')
  " If cursor has not moved inform user
  normal! zt
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
