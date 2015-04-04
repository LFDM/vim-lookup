let s:defaults = {
          \'javascript': {
          \  'substitute': ['\(\<\u\l\+\|\l\+\)\(\u\)' ,'\l\1-\l\2'],
          \  'extension' : '.js',
          \  'spec_extension' : '.spec.coffee',
          \  'callsign'  : '.',
          \  'func_def'  : [
          \     { 'lhs': 'function ', 'rhs': '\(\s\|(\)' },
          \     { 'lhs': 'this\.', 'rhs': ' = function' }
          \  ]
          \},
          \'coffee': {
          \  'substitute': ['\(\<\u\l\+\|\l\+\)\(\u\)' ,'\l\1-\l\2'],
          \  'extension' : '.js',
          \  'spec_extension' : '.spec.coffee',
          \  'callsign'  : '.',
          \  'func_def'  : [
          \     { 'lhs': 'describe .', 'rhs': '' },
          \  ]
          \},
          \'html' : {
          \  'substitute': ['\v(.*)', '\1-directive'],
          \  'extension' : '.js',
          \  'spec_extension' : '.spec.coffee',
          \  'callsign'  : '.',
          \  'func_def'  : []
          \}
      \}

let angular_file = '\v\.(js|less|spec.coffee|tpl.html)$'
let angular_service   = '\v(service|factory)\.js$'
let angular_directive = 'directive\.js$'

let g:lookup_file_opener = [
      \[
        \[
          \angular_service,
          \[
            \ [['source'], [angular_file, '.spec.coffee']]
          \]
        \],
        \[
          \angular_directive,
          \[
            \ [[angular_file, '.js'], [angular_file, '-tpl.html']],
            \ [[angular_file, '.spec.coffee', 18], [angular_file, '.less', 18]]
          \]
        \]
      \]
\]

let s:silent = 0

function! lookup#setup()
  let vars = [ 'substitute', 'extension', 'spec_extension', 'callsign', 'func_def' ]
  for var in vars
    call s:setVar(var)
  endfor

  "if !(exists('g:lookup_no_default_mappings') && g:lookup_no_default_mappings)
    "call s:set_default_mappings()
  "endif
endfunction

" Duplicated code - not good. But how to pass functions in vim?
" Exec is not helping, because we cannot save the return value of it
" then. Redir is also not helping in this case.
function! lookup#goToFuncOrFile()
  if !s:hasConfigurationDefined() | return | endif

  let s:silent = 1
  let jumped = lookup#goToFunc()
  let s:silent = 0
  if !jumped
    let s:silent = 1
    let jumped = lookup#goToFile()
    let s:silent = 0
    if !jumped
      call s:log('Could neither find file nor function')
    endif
  endif
  return jumped
endfunction

function! lookup#goToSpecFuncOrFile()
  if !s:hasConfigurationDefined() | return | endif

  let s:silent = 1
  let jumped = lookup#goToSpecFunc()
  let s:silent = 0
  if !jumped
    let s:silent = 1
    let jumped = lookup#goToSpecFile()
    let s:silent = 0
    if !jumped
      call s:log('Could neither find file nor function')
    endif
  endif
  return jumped
endfunction

function! lookup#goToFile()
  if !s:hasConfigurationDefined() | return | endif
  return s:goToFile(s:getCurrentWord(), b:lookup_extension)
endfunction

function! lookup#goToSpecFile()
  if !s:hasConfigurationDefined() | return | endif
  return s:goToFile(s:getCurrentWord(), b:lookup_spec_extension)
endfunction

function! lookup#goToFunc()
  return s:goToFunc(b:lookup_extension)
endfunction

function! lookup#goToSpecFunc()
  " Some extra work needs to be done when we are already in the file,
  " which holds the function definition to which spec we want to jump.
  let word = s:getCurrentWord()
  let pos = getpos('')
  let file_name = expand('%:p')
  let jumped = s:goToFunc(b:lookup_spec_extension)
  if jumped && file_name == expand('%:p')
    let jumped = 0
    try
      let short_file_name = expand('%')
      let spec_name = substitute(short_file_name, b:lookup_extension . '$', b:lookup_spec_extension, '')
      if spec_name != short_file_name
        try
          exec "find **/" . spec_name
          let jumped = s:goToFuncInFile(word)
        endtry
      else
        let jumped = s:goToFuncInFile(word)
      endif
    endtry
  endif

  if !jumped
    call s:log('Could not find spec function')
    " And jump back
    call setpos(file_name, pos)
  endif

  return jumped
endfunction

function! s:goToFunc(extension)
  if !s:hasConfigurationDefined() | return | endif

  let word = s:getCurrentWord()
  let pos = getpos('.')
  normal! b
  " If we were already at the start of the word, we've moved too far
  if s:getCurrentWord() != word
    normal! w
  endif
  " Check if we are at the beginning of the line
  if getpos('.')[2] != 1
    normal! h
    " Check if we are calling a function from another file
    if getline('.')[getpos('.')[2] - 1] == b:lookup_callsign
      normal! b
      " Restore the position so we can come back after we've left this file
      let file_name = s:getCurrentWord()
      call setpos('.', pos)
      try
        call s:goToFile(file_name, a:extension)
        return s:goToFuncInFile(word)
      endtry
    endif
  endif
  call setpos('.', pos)
  return  s:goToFuncInFile(word)
endfunction

function! s:goToFile(word, extension)
  let lhs = b:lookup_substitute[0]
  let rhs = b:lookup_substitute[1]
  let file_name = substitute(a:word, lhs ,rhs, 'g')
  if a:word != file_name
    let full_name = file_name . a:extension
    try
      exec "find **/" . full_name
      return 1
    catch
      call s:log("Lookup could not find a file named " . full_name)
    endtry
  endif
endfunction

function! s:goToFuncInFile(word)
  let pos = getpos('.')
  let jumped = 0
  for def in b:lookup_func_def
    if !jumped
      let pattern = def.lhs . a:word . def.rhs
      call search(pattern, 'w')
      " If cursor has not moved we are done, but check if we were already
      " there in the first place, which would also mean that we have a valid
      " match.
      if !(pos == getpos('.')) || getline('.') =~ pattern
        let jumped = 1
      endif
    endif
  endfor
  if jumped
    normal! zt
  else
    call s:log("Could not find a function named " . a:word)
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

function! s:log(msg)
  if !s:silent
    echo "lookup: " . a:msg
  endif
endfunction

function! s:getCurrentWord()
  let keyword_settings = &iskeyword
  let &iskeyword = keyword_settings . ',-'
  let word = expand('<cword>')
  let &iskeyword = keyword_settings
  return word
endfunction


function! lookup#open(key)
  if !has_key(g:lookup_window_opener, a:key)
    return
  endif

  let openers = get(g:lookup_window_opener, a:key)
  let file = expand('%:p')
  for opener in openers
    if file =~ opener.pattern
      call s:open_files(opener.windows, file)
      return
    endif
  endfor
endfunction

function! s:open_files(windows, source)
    " Calculate files we have access to
    let windows = s:setup_windows(a:windows, a:source)

    " Create all splits and open file
    let hor_i = 0
    for hor_splits in windows
      let vert_i = 0
      call s:moveTopLeft()

      for vert_split in hor_splits
        " When the window is defined
        let f = vert_split.file
        " When we are at the topleft file
        if f != '---'
          if hor_i == 0 && vert_i == 0
            exec "e ". f
          else
            call s:moveRight(vert_i)
            " When no vertical split has yet been done
            if hor_i == 0
              exec vert_split.cols . "vsp" . f
            else
              call s:moveRight(vert_i)
              call s:moveDown(hor_i - 1)
              exec vert_split.rows . "sp" . f
              call s:moveUp(hor_i - 1)
            endif

            call s:moveLeft(vert_i)
          endif
        endif
        let vert_i += 1
      endfor

      let hor_i += 1
    endfor

    call s:moveTopLeft()
endfunction

function! s:setup_windows(windows, source)
  let result = []
  for hor in a:windows
    let res = []
    for vert in hor
      let r = { 'rows': '', 'cols': '' }
      if has_key(vert, 'rows') | let r.rows = vert.rows | endif
      if has_key(vert, 'cols') | let r.cols = vert.cols | endif
      if has_key(vert, 'empty') && vert.empty
        let r.file = '---'
      else
        let r.file = s:generate_file_name(a:source, vert.substitute)
      endif
      call add(res, r)
    endfor
    if len(res) > 0
      call add(result, res)
    endif
  endfor
  return result
endfunction

function! s:generate_file_name(file, subst)
  return substitute(a:file, a:subst[0], a:subst[1], '')
endfunction

function! s:moveLeft(count)
  exec "normal! \<C-W>" . a:count . "h"
endfunction

function! s:moveRight(count)
  exec "normal! \<C-W>" . a:count . "l"
endfunction

function! s:moveLeft(count)
  exec "normal! \<C-W>" . a:count . "l"
endfunction

function! s:moveUp(count)
  exec "normal! \<C-W>" . a:count . "k"
endfunction

function! s:moveDown(count)
  exec "normal! \<C-W>" . a:count . "j"
endfunction

function! s:moveTopLeft()
  exec "normal! \<C-W>t"
endfunction

