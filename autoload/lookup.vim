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

let s:silent = 0

function! lookup#setup()
  let vars = [ 'substitute', 'extension', 'spec_extension', 'callsign', 'func_def' ]
  for var in vars
    call s:set_var(var)
  endfor

  "if !(exists('g:lookup_no_default_mappings') && g:lookup_no_default_mappings)
    "call s:set_default_mappings()
  "endif
endfunction

function! lookup#go_to_and_open_layout(key)
  let jumped = lookup#go_to_file()
  if jumped
    call lookup#open_layout(a:key)
  endif
endfunction

function! lookup#open_layout(key)
  if !has_key(g:lookup_layouts, a:key) | return | endif

  let openers = get(g:lookup_layouts, a:key)
  let file = expand('%:p')
  for opener in openers
    if file =~ opener.pattern
      call s:open_files(opener.windows, file)
      return
    endif
  endfor
endfunction

function! lookup#go_to_func_or_file()
  return s:go_to_func_or_file('lookup#go_to_func', 'lookup#go_to_file')
endfunction

function! lookup#go_to_spec_func_or_file()
  return s:go_to_func_or_file('lookup#go_to_spec_func', 'lookup#go_to_spec_file')
endfunction

function! lookup#go_to_file()
  if !s:has_configuration_defined() | return | endif
  return s:go_to_file(s:get_current_word(), b:lookup_extension)
endfunction

function! lookup#go_to_spec_file()
  if !s:has_configuration_defined() | return | endif
  return s:go_to_file(s:get_current_word(), b:lookup_spec_extension)
endfunction

function! lookup#go_to_func()
  return s:go_to_func(b:lookup_extension)
endfunction

function! lookup#go_to_spec_func()
  return s:go_to_spec_func()
endfunction

function! s:go_to_func_or_file(func_fn, file_fn)
  if !s:has_configuration_defined() | return | endif

  let s:silent = 1
  let jumped = {a:func_fn}()
  let s:silent = 0
  if !jumped
    let s:silent = 1
    let jumped = {a:file_fn}()
    let s:silent = 0
    if !jumped
      call s:log('Could neither find file nor function')
    endif
  endif
  return jumped
endfunction

function! s:go_to_spec_func()
  " Some extra work needs to be done when we are already in the file,
  " which holds the function definition to which spec we want to jump.
  let word = s:get_current_word()
  let pos = getpos('')
  let file_name = expand('%:p')
  let jumped = s:go_to_func(b:lookup_spec_extension)
  if jumped && file_name == expand('%:p')
    let jumped = 0
    try
      let short_file_name = expand('%')
      let spec_name = substitute(short_file_name, b:lookup_extension . '$', b:lookup_spec_extension, '')
      if spec_name != short_file_name
        try
          exec "find **/" . spec_name
          let jumped = s:go_to_func_in_file(word)
        endtry
      else
        let jumped = s:go_to_func_in_file(word)
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

function! s:go_to_func(extension)
  if !s:has_configuration_defined() | return | endif

  let word = s:get_current_word()
  let pos = getpos('.')
  normal! b
  " If we were already at the start of the word, we've moved too far
  if s:get_current_word() != word
    normal! w
  endif
  " Check if we are at the beginning of the line
  if getpos('.')[2] != 1
    normal! h
    " Check if we are calling a function from another file
    if getline('.')[getpos('.')[2] - 1] == b:lookup_callsign
      normal! b
      " Restore the position so we can come back after we've left this file
      let file_name = s:get_current_word()
      call setpos('.', pos)
      try
        call s:go_to_file(file_name, a:extension)
        return s:go_to_func_in_file(word)
      endtry
    endif
  endif
  call setpos('.', pos)
  return  s:go_to_func_in_file(word)
endfunction

function! s:go_to_file(word, extension)
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

function! s:go_to_func_in_file(word)
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

function! s:open_files(windows, source)
    " Calculate files we have access to
    let windows = s:setup_windows(a:windows, a:source)

    " Create all splits and open file
    let hor_i = 0
    for hor_splits in windows
      let vert_i = 0
      call s:move_top_left()

      for vert_split in hor_splits
        " When the window is defined
        let f = vert_split.file
        " When we are at the topleft file
        if f != '---'
          if hor_i == 0 && vert_i == 0
            exec "e ". f
          else
            call s:move_right(vert_i)
            " When no vertical split has yet been done
            if hor_i == 0
              exec vert_split.cols . "vsp" . f
            else
              call s:move_right(vert_i)
              call s:move_down(hor_i - 1)
              exec vert_split.rows . "sp" . f
              call s:move_up(hor_i - 1)
            endif

            call s:move_left(vert_i)
          endif
        endif
        let vert_i += 1
      endfor

      let hor_i += 1
    endfor

    call s:move_top_left()
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

function! s:get_current_word()
  let keyword_settings = &iskeyword
  let &iskeyword = keyword_settings . ',-'
  let word = expand('<cword>')
  let &iskeyword = keyword_settings
  return word
endfunction

function! s:generate_file_name(file, subst)
  return substitute(a:file, a:subst[0], a:subst[1], '')
endfunction

let s:window_command = "normal! \<C-W>"

function! s:move_left(count)
  exec s:window_command . a:count . "h"
endfunction

function! s:move_right(count)
  exec s:window_command . a:count . "l"
endfunction

function! s:move_up(count)
  exec s:window_command . a:count . "k"
endfunction

function! s:move_down(count)
  exec s:window_command . a:count . "j"
endfunction

function! s:move_top_left()
  exec s:window_command . "t"
endfunction

function! s:get_value(key)
  if exists('g:lookup_customizations')
    let custom = s:lookup_key(g:lookup_customizations, a:key)
    if custom | return custom | endif
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

function! s:set_var(key)
  call setbufvar(bufname('%'), 'lookup_' . a:key, s:get_value(a:key))
endfunction

function! s:has_configuration_defined()
  if (exists('g:lookup_customizations') && has_key(g:lookup_customizations, &ft)) || has_key(s:defaults, &ft)
    return 1
  endif
endfunction

function! s:log(msg)
  if !s:silent
    echo "lookup: " . a:msg
  endif
endfunction


