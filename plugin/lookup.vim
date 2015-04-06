if exists('g:loaded_lookup') || &cp
  finish
endif

if !exists("g:lookup_layouts") | let g:lookup_layouts = {} | endif
if !exists("g:lookup_file_mappings") | let g:lookup_file_mappings = {} | endif

let g:lookup_substitutions = {
  \ 'camel_case_to_hyphenated': ['\(\<\u\l\+\|\l\+\)\(\u\)', '\l\1-\l\2', 'g'],
  \ 'camel_case_to_underscored': ['\(\<\u\l\+\|\l\+\)\(\u\)', '\l\1_\l\2', 'g'],
  \ 'to_lowercase': ['\(.*\)', '\l\1', '']
\}

let g:lookup_default_func_defs = {
  \'javascript': [
  \  { 'lhs': 'function ', 'rhs': '\s\?(' },
  \  { 'lhs': 'this\.', 'rhs': ' = ' },
  \  { 'lhs': '\.', 'rhs': ' = function' },
  \  { 'lhs': 'describe .', 'rhs': '' },
  \],
  \'coffee': [
  \  { 'rhs': '= \((.*)\)\? \?[-=]>' },
  \  { 'lhs': 'describe .', 'rhs': '' },
  \],
  \'ruby': [
  \  { 'lhs': 'describe ..\?' },
  \  { 'lhs': 'def ' }
  \]
\}


let g:lookup_default_substitutes = {
  \'javascript': [
  \  g:lookup_substitutions.camel_case_to_hyphenated,
  \  g:lookup_substitutions.to_lowercase
  \],
  \'coffee': [
  \  g:lookup_substitutions.camel_case_to_underscored,
  \  g:lookup_substitutions.camel_case_to_hyphenated,
  \  g:lookup_substitutions.to_lowercase
  \],
  \'ruby': [
  \  g:lookup_substitutions.camel_case_to_underscored
  \]
\}


augroup lookup
  au Filetype * call lookup#setup()
augroup END

command! LookupGoTo call lookup#go_to_func_or_file()
command! LookupGoToSpec call lookup#go_to_spec_func_or_file()
command! -nargs=1 LookupOpenFile call lookup#open_file(<f-args>)
command! -nargs=1 LookupOpenLayout call lookup#open_layout(<f-args>)
command! -nargs=1 LookupGoToAndOpenLayout call lookup#go_to_and_open_layout(<f-args>)

if !(exists('g:lookup_no_default_mappings') && g:lookup_no_default_mappings)
  noremap <leader>lg :LookupGoTo<cr>
  noremap <leader>ls :LookupGoToSpec<cr>
  noremap <leader>lo :LookupOpenLayout 
  noremap <leader>lf :LookupOpenFile 
endif

let g:loaded_lookup = 1
