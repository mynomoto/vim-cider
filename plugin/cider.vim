" cider.vim
" Maintainer:   Juho Teperi

if exists("g:loaded_cider") || v:version < 700 || &cp
  finish
endif
let g:loaded_cider = 1

" FIXME: From fireplace
function! s:opfunc(type) abort
  let sel_save = &selection
  let cb_save = &clipboard
  let reg_save = @@
  try
    set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
    if type(a:type) == type(0)
      let open = '[[{(]'
      let close = '[]})]'
      if getline('.')[col('.')-1] =~# close
        let [line1, col1] = searchpairpos(open, '', close, 'bn', g:fireplace#skip)
        let [line2, col2] = [line('.'), col('.')]
      else
        let [line1, col1] = searchpairpos(open, '', close, 'bcn', g:fireplace#skip)
        let [line2, col2] = searchpairpos(open, '', close, 'n', g:fireplace#skip)
      endif
      while col1 > 1 && getline(line1)[col1-2] =~# '[#''`~@]'
        let col1 -= 1
      endwhile
      call setpos("'[", [0, line1, col1, 0])
      call setpos("']", [0, line2, col2, 0])
      silent exe "normal! `[v`]y"
    elseif a:type =~# '^.$'
      silent exe "normal! `<" . a:type . "`>y"
    elseif a:type ==# 'line'
      silent exe "normal! '[V']y"
    elseif a:type ==# 'block'
      silent exe "normal! `[\<C-V>`]y"
    elseif a:type ==# 'outer'
      call searchpair('(','',')', 'Wbcr', g:fireplace#skip)
      silent exe "normal! vaby"
    else
      silent exe "normal! `[v`]y"
    endif
    redraw
    return repeat("\n", line("'<")-1) . repeat(" ", col("'<")-1) . @@
  finally
    let @@ = reg_save
    let &selection = sel_save
    let &clipboard = cb_save
  endtry
endfunction

" Format operation
function! s:formatop(type) abort
  let reg_save = @@
  let sel_save = &selection
  let cb_save = &clipboard
  try
    set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
    let expr = s:opfunc(a:type)
    " Remove additional newlines from start of expression
    let res = fireplace#message({'op': 'format-code', 'code': substitute(expr, '^\n\+', '', '')})
    " Remove additional spaces from start of the first line as code is
    " already indented?
    let formatted = substitute(get(get(res, 0), 'formatted-code'), '^ \+', '', '')
    let @@ = formatted
    if @@ !~# '^\n*$'
      normal! gvp
    endif
  catch /^Clojure:/
    return ''
  finally
    let @@ = reg_save
    let &selection = sel_save
    let &clipboard = cb_save
  endtry
endfunction

nnoremap <silent> <Plug>CiderFormat :<C-U>set opfunc=<SID>formatop<CR>g@
xnoremap <silent> <Plug>CiderFormat :<C-U>call <SID>formatop(visualmode())<CR>
nnoremap <silent> <Plug>CiderCountFormat :<C-U>call <SID>formatop(v:count)<CR>

function! s:undef() abort
  let ns = fireplace#ns()
  let s = expand('<cword>')
  let res = fireplace#message({'op': 'undef', 'ns': ns, 'symbol': s})
  echo 'Undef ' . ns . '/' . s
endfunction

nnoremap <silent> <Plug>CiderUndef :<C-U>call <SID>undef()<CR>

function! s:cleanNs() abort
  " FIXME: Moves cursor

  let p = expand('%:p')
  normal! ggw

  let [line1, col1] = searchpairpos('(', '', ')', 'bc')
  let [line2, col2] = searchpairpos('(', '', ')', 'n')

  while col1 > 1 && getline(line1)[col1-2] =~# '[#''`~@]'
    let col1 -= 1
  endwhile
  call setpos("'[", [0, line1, col1, 0])
  call setpos("']", [0, line2, col2, 0])

  if expand('<cword>') ==? 'ns'
    let res = fireplace#message({'op': 'clean-ns', 'path': p})
    let @@ = get(res[0], 'ns')
    " FIXME: Adds unuecessary line before and after
    silent exe "normal! `[v`]p"
    " FIXME: Simplify?
    silent exe "normal! `[v`]=="
  endif
endfunction

nnoremap <silent> <Plug>RefactorCleanNs :<C-U>call <SID>cleanNs()<CR>

function! s:set_up() abort
  if get(g:, 'cider_no_maps') | return | endif

  nmap <buffer> cf <Plug>CiderFormat
  nmap <buffer> cff <Plug>CiderCountFormat
  nmap <buffer> cF ggcfG

  nmap <buffer> cdd <Plug>CiderUndef

  nmap <buffer> <F4> <Plug>RefactorCleanNs
endfunction

augroup cider_eval
  autocmd!
  autocmd FileType clojure call s:set_up()
augroup END
