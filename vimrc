" File: vimrc
" Maintainer: Paul Huang <aphroteus at gmail dot com>

" Vundle {{{

set nocompatible              " be iMproved, required
filetype off                  " required

let winshell = (has('win32') || has('win64')) && &shellcmdflag =~ '/'
let vimdir = winshell ? '$HOME/vimfiles' : '$HOME/.vim'

let vundlereadme=expand(vimdir . '/bundle/Vundle.vim/README.md')
if !filereadable(vundlereadme)
  silent execute "!mkdir " . expand(vimdir . '/bundle')
  silent execute "!git clone https://github.com/VundleVim/Vundle.vim.git " . expand(vimdir . "/bundle/Vundle.vim")
endif

" set the runtime path to include Vundle and initialize
"set rtp+=~/vimfiles/bundle/Vundle.vim
let &runtimepath .= ',' . expand(vimdir . '/bundle/Vundle.vim')
"call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/vimfiles/bundle')
call vundle#begin(expand(vimdir . '/bundle'))

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

Plugin 'vim-airline/vim-airline'
Plugin 'tpope/vim-fugitive'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'crusoexia/vim-monokai'
Plugin 'mileszs/ack.vim'
Plugin 'aphroteus/vim-uefi'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

" }}}

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

  if has("gui_gtk2")
    set guifont=Inconsolata\ for\ Powerline\ h17
  elseif has("x11")
    " Also for GTK 1
    set guifont=*-lucidatypewriter-medium-r-normal-*-*-180-*-*-m-*-*
  elseif has("gui_win32")
    " To maximize the initial Vim window under Windows
    " http://vim.wikia.com/wiki/Maximize_or_set_initial_window_size
    autocmd GUIEnter * simalt ~x
    set guifont=Inconsolata_for_Powerline:h14:cANSI
    " Avoid unable to open swap file on Windows 7
    set directory=$TEMP
  endif
endif
" }}}

" Basic config {{{
silent! colorscheme monokai
set encoding=utf-8

" Rewrite to xterm
behave xterm

" Tab in my view will be stop by 2
set tabstop=2

" Only Space without Tab
set softtabstop=2
set expandtab
set shiftwidth=2

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
" }}}

map zz :e $MYVIMRC<CR>

" Movement {{{
" Delete a buffer correctly
nmap bd :bp<CR>:bd #<CR>

" Hotkey Go Next(gn) and Go Back(gb) for buffer
nmap <expr> gn (&buftype is# "quickfix" ? "" : (&buftype is# "nofile" ? "" : ":bn<CR>"))
nmap <expr> gb (&buftype is# "quickfix" ? "" : (&buftype is# "nofile" ? "" : ":bp<CR>"))
" }}}

" Exclude quickfix buffer from :bnext or :bprevious
autocmd FileType qf set nobuflisted

" Ignore search path
set wildignore+=.git/**,Build/**,BaseTools/**,BuildTools/**,EdkCompatibilityPkg/**

imap <Leader>[ // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - start<ESC>
imap <Leader>] // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - end<ESC>

nmap <A-n> :cnext<CR>
nmap <A-p> :cprev<CR>


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


" Set current working directory {{{
function! s:setcwd()
  let cph = expand('%:p:h', 1)
  if cph =~ '^.\+://' | retu | en
  for mkr in ['.git/', '.hg/', '.svn/', '.bzr/', '_darcs/', '.vimprojects']
    let wd = call('find'.(mkr =~ '/$' ? 'dir' : 'file'), [mkr, fnameescape(cph.';')])
    if wd != '' | let &acd = 0 | brea | en
  endfo
  exe 'lc!' fnameescape(wd == '' ? cph : substitute(wd, mkr.'$', '.', ''))
endfunction

autocmd BufEnter * call s:setcwd()
" }}}


" Binary {{{
nmap <C-H> :Hexmode<CR>

" ex command for toggling hex mode - define mapping if desired
command -bar Hexmode call ToggleHex()

" helper function to toggle hex mode
function ToggleHex()
  " hex mode should be considered a read-only operation
  " save values for modified and read-only for restoration later,
  " and clear the read-only flag for now
  let l:modified=&mod
  let l:oldreadonly=&readonly
  let &readonly=0
  let l:oldmodifiable=&modifiable
  let &modifiable=1
  if !exists("b:editHex") || !b:editHex
    " save old options
    let b:oldft=&ft
    let b:oldbin=&bin
    " set new options
    setlocal binary " make sure it overrides any textwidth, etc.
    silent :e " this will reload the file without trickeries
              "(DOS line endings will be shown entirely )
    let &ft="xxd"
    " set status
    let b:editHex=1
    " switch to hex editor
    silent execute "%!xxd"
  endif
  " restore values for modified and read only state
  let &mod=l:modified
  let &readonly=l:oldreadonly
  let &modifiable=l:oldmodifiable
endfunction

" autocmds to automatically enter hex mode and handle file writes properly
if has("autocmd")
  " vim -b : edit binary using xxd-format!
  augroup Binary
    au!

    " set binary option for all binary files before reading them
    au BufReadPre *.fd,*.fv,*.rom,*.bin,*.hex setlocal binary

    " if on a fresh read the buffer variable is already set, it's wrong
    au BufReadPost *
          \ if exists('b:editHex') && b:editHex |
          \   let b:editHex = 0 |
          \ endif

    " convert to hex on startup for binary files automatically
    au BufReadPost *
          \ if &binary | Hexmode | endif

    " When the text is freed, the next time the buffer is made active it will
    " re-read the text and thus not match the correct mode, we will need to
    " convert it again if the buffer is again loaded.
    au BufUnload *
          \ if getbufvar(expand("<afile>"), 'editHex') == 1 |
          \   call setbufvar(expand("<afile>"), 'editHex', 0) |
          \ endif

    " before writing a file when editing in hex mode, convert back to non-hex
    au BufWritePre *
          \ if exists("b:editHex") && b:editHex && &binary |
          \  let oldro=&ro | let &ro=0 |
          \  let oldma=&ma | let &ma=1 |
          \  silent execute "%!xxd -r" |
          \  let &ma=oldma | let &ro=oldro |
          \  unlet oldma | unlet oldro |
          \ endif

    " after writing a binary file, if we're in hex mode, restore hex mode
    au BufWritePost *
          \ if exists("b:editHex") && b:editHex && &binary |
          \  let oldro=&ro | let &ro=0 |
          \  let oldma=&ma | let &ma=1 |
          \  silent execute "%!xxd" |
          \  execute "set nomod" |
          \  let &ma=oldma | let &ro=oldro |
          \  unlet oldma | unlet oldro |
          \ endif
  augroup END
endif
" }}}


"----------------------
" vim:foldmethod=marker
"----------------------