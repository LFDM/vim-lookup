if exists('g:loaded_lookup') || &cp
  finish
endif

augroup lookup
  au Filetype * call lookup#setup()
augroup END

command LookupGoTo call lookup#goToFuncOrFile()
command LookupGoToSpec call lookup#goToSpecFuncOrFile()

let g:loaded_lookup = 1
