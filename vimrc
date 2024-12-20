" File: vimrc
" Maintainer: Paul Huang <aphroteus at gmail dot com>

" Platform dependency {{{
if has("unix")
  " For Cygwin and Linux
  if has("win32unix")
    " For Cygwin but not Linux

    " Make cursor dynamic change
    let &t_ti.="\e[1 q"
    let &t_SI.="\e[5 q"
    let &t_EI.="\e[1 q"
    let &t_te.="\e[0 q"
    
    let Tlist_Ctags_Cmd="/usr/bin/ctags"
    if has('mouse')
      set mouse=a
    endif
    
  else
    " For Linux but not Cygwin
    source $VIMRUNTIME/mswin.vim
    behave mswin

    " Remove swap files from working directory
    set directory=/tmp
  endif
elseif has("win32")
  " For Windows-native Vim

  " Add Windows feature
  source $VIMRUNTIME/vimrc_example.vim
  source $VIMRUNTIME/mswin.vim
  behave mswin

  " Fix language issue on menu bar and toolbar
  let $LANG="en_US.UTF-8"
  set langmenu=en_US.UTF-8
  source $VIMRUNTIME/delmenu.vim
  source $VIMRUNTIME/menu.vim

  let $PATH .= ';C:\cygwin64\bin'. expand(';$HOME\bin')

  " Remove swap files from working directory
  set directory=$TEMP
else
  echoerr "Unknown OS"
endif
" }}}


" Font and menu for GVim {{{
if has("gui_running")

  " Keep only edit area
  set guioptions -=m "remove menu bar
  set guioptions -=T "remove toolbar
  set guioptions -=r "remove right-hand scroll bar
  set guioptions -=L "remove left-hand scroll bar

  if (has("gui_gtk2") || has("gui_gtk3"))
    " Trying to maximize initial window size on Linux
    " http://vim.wikia.com/wiki/Maximize_or_set_initial_window_size
    set lines=50
    set columns=170
    set guifont=Inconsolata\ for\ Powerline\ Medium\ 17
  elseif has("x11")
    " Also for GTK 1
    set guifont=*-lucidatypewriter-medium-r-normal-*-*-180-*-*-m-*-*
  elseif has("gui_win32")
    " To maximize initial window size on Windows
    " http://vim.wikia.com/wiki/Maximize_or_set_initial_window_size
    autocmd GUIEnter * simalt ~x
    set guifont=Inconsolata_for_Powerline:h14:cANSI
  endif
else
  set t_Co=256
endif
" }}}


" Basic config {{{
silent! colorscheme monokai
set encoding=utf-8

" Rewrite to xterm
behave xterm

if 0
  " Tab in my view will be stop by 2
  set tabstop=2
  " Only Space without Tab
  set softtabstop=2
  set shiftwidth=2
  set expandtab
endif

set autoindent

set textwidth=120

" Highlight and ignore case the Search
set hlsearch incsearch
set ignorecase

" Highlight current line
set cursorline

set noundofile
set nobackup

" Show line number
set number

" Always show status line
set laststatus=2

syntax on

map zz :e $MYVIMRC<CR>

" Ignore search path
set wildignore+=.repo/**,.git/**,Build/**,BaseTools/**,BuildTools/**

set nocompatible
filetype plugin indent on

autocmd FileType text,markdown setlocal spell spelllang=en_us
" }}}


" Movement {{{
" Delete a buffer correctly
nmap bd :bp<CR>:bd #<CR>

" Exclude quickfix buffer from :bnext or :bprevious
autocmd FileType qf set nobuflisted

" Hotkey Go Next(gn) and Go Back(gb) for buffer
nmap <expr> gn (&buftype is# "quickfix" ? "" : (&buftype is# "nofile" ? "" : ":bn<CR>"))
nmap <expr> gb (&buftype is# "quickfix" ? "" : (&buftype is# "nofile" ? "" : ":bp<CR>"))

" Hotkey Alt+n and Alt+p for navigating the results of quickfix
nmap <A-n> :cnext<CR>
nmap <A-p> :cprev<CR>
" }}}


" Coding {{{
imap <Leader>[ // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - start<ESC>
imap <Leader>] // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - end<ESC>

" Copy relative path of cwd to clipboard, working with setcwd
if has("clipboard")
  nmap cs :let @+=expand("%")<CR>:echo @+<CR>
endif
" }}}


" vim-airline {{{
let g:airline#extensions#branch#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
" }}}


" ctrlp {{{
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_max_files = 0
let g:ctrlp_max_depth = 40
let g:ctrlp_regexp = 1
let g:ctrlp_user_command ='rg -F --files %s'
" }}}


" ack {{{
if executable('rg')
  let g:ackprg = 'rg --vimgrep --smart-case'
elseif executable('ag')
  let g:ackprg = 'ag --vimgrep --smart-case'
endif
let g:ackhighlight = 1
map <F2> :Ack!<CR>
nmap <F3> :Ack!<Space>
" }}}


" vim-commentary {{{
autocmd FileType uefidec,uefidsc,uefifdf,uefiinf,sdl setlocal commentstring=#\ %s
autocmd FileType uefic,uefiuni,uefivfr,asl setlocal commentstring=//\ %s
" }}}


" rust.vim {{{
let g:rustfmt_autosave = 1
" }}}


" python pfs black {{{
if has('win32')
  let g:black_virtualenv = expand('$HOME/vimfiles/black')
endif
augroup black_on_save
  autocmd!
  autocmd BufWritePre *.py Black
augroup END
" }}}


" Set current working directory {{{
function! s:setcwd()
  let cph = expand('%:p:h', 1)
  if cph =~ '^.\+://' | retu | en
  for mkr in ['.git/', '.repo/', '.hg/', '.svn/', '.bzr/', '_darcs/', '.vimprojects']
    let wd = call('find'.(mkr =~ '/$' ? 'dir' : 'file'), [mkr, fnameescape(cph.';')])
    if wd != '' | let &acd = 0 | brea | en
  endfo
  exe 'lc!' fnameescape(wd == '' ? cph : substitute(wd, mkr.'$', '.', ''))
endfunction

autocmd BufEnter * call s:setcwd()
" }}}


" Binary {{{
" Refer :h hex-editing
" vim -b : edit binary using xxd-format!
augroup Binary
  autocmd!
  autocmd BufReadPre  *.fd,*.fv,*.rom,*.bin,*.efi,*.exe,*.hex set binary
  autocmd BufReadPost *
    \ if &binary
    \ |   execute "silent %!xxd"
    \ |   set filetype=xxd
    \ |   redraw
    \ | endif
  autocmd BufWritePre *
    \ if &binary
    \ |   let s:view = winsaveview()
    \ |   execute "silent %!xxd -r"
    \ | endif
  autocmd BufWritePost *
    \ if &binary
    \ |   execute "silent %!xxd"
    \ |   set nomodified
    \ |   call winrestview(s:view)
    \ |   redraw
    \ | endif
augroup END
" }}}


"----------------------
" vim:foldmethod=marker
"----------------------
