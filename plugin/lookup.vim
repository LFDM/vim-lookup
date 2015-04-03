if exists('g:loaded_lookup') || &cp
  finish
endif

"if !exists('g:lookup_trigger')
  "finish
"endif

augroup lookup
  au Filetype * call lookup#setup()
augroup END

let g:loaded_lookup = 1
