if exists('g:loaded_lookup') || &cp
  finish
endif

if !exists("g:lookup_window_opener")
  let g:lookup_window_opener = {}
endif

augroup lookup
  au Filetype * call lookup#setup()
augroup END

command! LookupGoTo call lookup#goToFuncOrFile()
command! LookupGoToSpec call lookup#goToSpecFuncOrFile()

let g:loaded_lookup = 1
