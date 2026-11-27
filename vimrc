vim9script
# File: vimrc
# Maintainer: Paul Huang <aphroteus at gmail dot com>

# Platform dependency {{{
def CleanWinPathEntry(entry: string): string
  var p = trim(substitute(trim(entry), '^"\(.*\)"$', '\1', ''))
  p = substitute(p, '/', '\\', 'g')
  var prefix = p =~# '^\\\\' ? '\\' : ''
  var rest = empty(prefix) ? p : substitute(p, '^\\\+', '', '')
  rest = substitute(rest, '\\\+', '\\', 'g')
  p = prefix .. rest
  if p !~# '^[A-Za-z]:\\$'
    p = substitute(p, '\\\+$', '', '')
  endif
  return p
enddef

def AppendWinPath(dirs: list<string>): void
  var existing: dict<bool> = {}
  for entry in split($PATH, ';')
    var norm = tolower(CleanWinPathEntry(entry))
    if !empty(norm)
      existing[norm] = true
    endif
  endfor

  for dir in dirs
    if empty(dir) || !isdirectory(dir)
      continue
    endif
    var clean = CleanWinPathEntry(dir)
    var norm = tolower(clean)
    if empty(norm) || has_key(existing, norm)
      continue
    endif
    if empty($PATH)
      $PATH = clean
    elseif $PATH =~# ';$'
      $PATH ..= clean
    else
      $PATH ..= ';' .. clean
    endif
    existing[norm] = true
  endfor
enddef

if has('unix')
  # For Cygwin and Linux
  if has('win32unix')
    # For Cygwin but not Linux

    if !has('gui_running')
      # Make cursor dynamic change (idempotent across vimrc reloads)
      if stridx(&t_ti, "\e[1 q") < 0
        &t_ti ..= "\e[1 q"
      endif
      if stridx(&t_SI, "\e[5 q") < 0
        &t_SI ..= "\e[5 q"
      endif
      if stridx(&t_EI, "\e[1 q") < 0
        &t_EI ..= "\e[1 q"
      endif
      if stridx(&t_te, "\e[0 q") < 0
        &t_te ..= "\e[0 q"
      endif
    endif

    if has('mouse')
      set mouse=a
    endif

  else
    # For Linux but not Cygwin
    # Remove swap files from working directory with unique path encoding
    set directory=/tmp//
  endif
elseif has('win32')
  # For Windows-native Vim
  AppendWinPath(['C:\cygwin64\bin', !empty($HOME) ? expand('$HOME') .. '\bin' : ''])

  # Remove swap files from working directory with unique path encoding
  set directory=$TEMP//
else
  echoerr 'Unknown OS'
endif
# }}}


# Font and menu for GVim {{{
if has('gui_running')

  # Keep only edit area
  set guioptions-=m # remove menu bar
  set guioptions-=T # remove toolbar
  set guioptions-=r # remove right-hand scroll bar
  set guioptions-=L # remove left-hand scroll bar

  if has('gui_gtk2') || has('gui_gtk3')
    # Trying to maximize initial window size on Linux
    # http://vim.wikia.com/wiki/Maximize_or_set_initial_window_size
    set lines=50
    set columns=170
    set guifont=Inconsolata\ for\ Powerline\ Medium\ 17
  elseif has('gui_win32')
    # To maximize initial window size on Windows
    # http://vim.wikia.com/wiki/Maximize_or_set_initial_window_size
    augroup GuiWin32Init
      autocmd!
      autocmd GUIEnter * simalt ~x
    augroup END
    set guifont=Inconsolata_for_Powerline:h14:cANSI
  endif
else
  set t_Co=256
endif
# }}}


# Basic config {{{
const VIMRC_FILE = resolve(expand('<sfile>:p'))
if &compatible
  # When invoked via -u, :vim9script restores Vi 'cpoptions' at EOF; reset on SourcePost
  set nocompatible
  augroup VimrcCpo
    autocmd!
    autocmd SourcePost * if resolve(expand('<afile>:p')) ==? VIMRC_FILE | set cpo&vim | autocmd! VimrcCpo | endif
  augroup END
endif
set encoding=utf-8      # Set internal encoding to UTF-8

set autoindent          # Preserve previous line indentation for all filetypes
set cursorline          # Highlight current line
set hlsearch            # Highlight search matches
set ignorecase          # Ignore case when searching
set incsearch           # Search as characters are typed
set laststatus=2        # Always show status line
set nobackup            # Do not create backup files
set noerrorbells        # Do not beep or flash on errors
set noundofile          # Do not create undo files
set number              # Show line number
if exists('+smoothscroll')
  set smoothscroll      # Enable smooth scrolling
endif
set textwidth=120       # Set maximum line width
set wildignore+=.repo/**,.git/**,Build/**,BaseTools/**,BuildTools/** # Ignore search path
if false
  # Tab and Indentation Settings {{{
  # Use spaces instead of tabs
  set expandtab
  # Number of spaces that a <Tab> in the file counts for
  set tabstop=4
  # Number of spaces to use for each step of (auto)indent
  set shiftwidth=4
  # When >0, <Tab> inserts <softtabstop> worth of spaces.
  # Makes tabbing behavior consistent with shiftwidth for inserting spaces.
  set softtabstop=4
  # }}}
endif

# editorconfig {{{
if has('patch-9.0.1799')
  packadd! editorconfig
endif
# }}}

# comment {{{
if has('patch-9.1.0375')
  packadd! comment
endif
# }}}

filetype plugin indent on
syntax on

silent! colorscheme monokai

augroup SpellSettings
  autocmd!
  autocmd FileType text,markdown setlocal spell spelllang=en_us
augroup END

nnoremap <silent> <Leader>ev <Cmd>edit $MYVIMRC<CR>
nnoremap <silent> <Leader>sv <Cmd>source $MYVIMRC<CR><Cmd>echo "vimrc reloaded!"<CR>
# }}}


# Clipboard {{{
if has('clipboard')
  # Keep unnamed register decoupled from system clipboard to prevent dd/x from clobbering it
  # Copy relative path of cwd to clipboard, working with plugin/cwd.vim
  nnoremap <silent> cs <ScriptCmd>@+ = expand("%")<CR><ScriptCmd>echo @+<CR>

  # Modern clipboard shortcut mappings (Windows CUA style without mswin toxicity)
  # Normal mode: paste clipboard content and position cursor at the end
  nnoremap <C-v> "+gP

  # Visual mode: copy, cut, paste/replace selection with clipboard content
  vnoremap <C-c> "+y
  vnoremap <C-x> "+x
  vnoremap <C-v> "+p

  # Insert mode: paste clipboard with indentation preservation and undo boundary
  inoremap <C-v> <C-g>u<C-r><C-p>+

  # Command-line mode: paste clipboard text into command/search line
  cnoremap <C-v> <C-r>+
endif
# }}}


# Movement {{{
# Delete a buffer correctly
nnoremap <silent> <Leader>bd <Cmd>Bdelete<CR>

# Exclude quickfix buffer from :bnext or :bprevious
augroup QuickfixSettings
  autocmd!
  autocmd FileType qf setlocal nobuflisted
augroup END

# Hotkey Next(]b) and Back([b) for buffer
nnoremap <expr> ]b (&buftype ==# 'quickfix' <Bar><Bar> &buftype ==# 'nofile' ? '' : '<Cmd>bnext<CR>')
nnoremap <expr> [b (&buftype ==# 'quickfix' <Bar><Bar> &buftype ==# 'nofile' ? '' : '<Cmd>bprevious<CR>')

# Hotkey Alt+n and Alt+p for navigating the results of quickfix
nnoremap <A-n> <Cmd>cnext<CR>
nnoremap <A-p> <Cmd>cprev<CR>
# }}}


# Coding {{{
inoremap <Leader>[ // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - start<ESC>
inoremap <Leader>] // (PaulHuang-<C-R>=strftime('%Y%m%d')<C-M>-00) - end<ESC>
# }}}


# vim-airline {{{
g:airline_powerline_fonts = 1
g:airline#extensions#tabline#enabled = 1
g:airline_extensions = ['quickfix', 'term', 'ctrlp', 'whitespace', 'tabline', 'searchcount']
# }}}


# vim-airline-themes {{{
g:airline_theme = 'molokai'
# }}}


# ctrlp {{{
g:ctrlp_working_path_mode = 'wa'
g:ctrlp_regexp = 1
if executable('rg')
  g:ctrlp_user_command = 'rg --files %s'
endif
g:ctrlp_clear_cache_on_exit = 0
# }}}


# rust.vim {{{
g:rustfmt_autosave = 1
# }}}


# python pfs black {{{
if has('win32')
  g:black_virtualenv = expand('$HOME/vimfiles/black')
endif
augroup BlackOnSave
  autocmd!
  autocmd BufWritePre *.py Black
augroup END
# }}}


# ----------------------
# vim:foldmethod=marker
# ----------------------
