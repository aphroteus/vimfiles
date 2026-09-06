vim9script
# Plugin for binary file inspection and hex editing
# Maintainer: Paul Huang

if !executable('xxd')
  def StubWarn(): void
    echoerr "xxd executable not found in PATH"
  enddef
  command! -bar HexToggle StubWarn()
  command! -bar -nargs=? HexMode StubWarn()
  finish
endif

const BINARY_EXTENSIONS = '*.fd,*.fv,*.rom,*.bin,*.efi,*.exe,*.hex'

def GetXxdCmd(): string
  var opt = (exists('g:binary_xxd_options') && !empty(g:binary_xxd_options) ? ' ' .. g:binary_xxd_options : '')
  return 'silent :%!xxd' .. opt
enddef

def BinaryReadPre(): void
  setlocal binary nofixendofline fileformat=unix
enddef

def ConvertToHex(): void
  if get(b:, 'in_hex_mode', false)
    return
  endif

  if !exists('b:binary_orig_ft')
    b:binary_orig_ft = &l:filetype
    b:binary_orig_bin = &l:binary
    b:binary_orig_ff = &l:fileformat
  endif

  var was_modified = &l:modified
  setlocal binary nofixendofline fileformat=unix
  execute GetXxdCmd()
  setlocal filetype=xxd
  if !was_modified
    setlocal nomodified
  endif
  b:in_hex_mode = true
  redraw
enddef

def ConvertToBinary(): void
  if !get(b:, 'in_hex_mode', false)
    return
  endif

  var was_modified = &l:modified
  execute 'silent :%!xxd -r'

  if exists('b:binary_orig_ft')
    execute 'setlocal filetype=' .. fnameescape(b:binary_orig_ft)
    if !b:binary_orig_bin
      setlocal nobinary
    endif
    execute 'setlocal fileformat=' .. fnameescape(b:binary_orig_ff)
    unlet b:binary_orig_ft b:binary_orig_bin b:binary_orig_ff
  else
    setlocal nobinary
  endif

  if !was_modified
    setlocal nomodified
  endif
  b:in_hex_mode = false
  redraw
enddef

def BinaryReadPost(): void
  if &l:binary && !get(b:, 'in_hex_mode', false)
    ConvertToHex()
  endif
enddef

def BinaryWritePre(): void
  if get(b:, 'in_hex_mode', false)
    b:binary_view = winsaveview()
    execute 'silent :%!xxd -r'
  endif
enddef

def BinaryWritePost(): void
  if get(b:, 'in_hex_mode', false)
    execute GetXxdCmd()
    setlocal nomodified
    if exists('b:binary_view')
      winrestview(b:binary_view)
      unlet b:binary_view
    endif
    redraw
  endif
enddef

def ToggleHex(): void
  if get(b:, 'in_hex_mode', false)
    ConvertToBinary()
  else
    ConvertToHex()
  endif
enddef

def SetHexMode(enable: bool): void
  if enable
    ConvertToHex()
  else
    ConvertToBinary()
  endif
enddef

def ShowHexStatus(): void
  if get(b:, 'in_hex_mode', false)
    echo "Hex mode: ON"
  else
    echo "Hex mode: OFF"
  endif
enddef

def HexModeCmd(arg: string = ''): void
  var mode = trim(arg)->tolower()
  if mode ==# 'on'
    SetHexMode(true)
  elseif mode ==# 'off'
    SetHexMode(false)
  elseif mode ==# 'toggle' || empty(mode)
    ToggleHex()
  elseif mode ==# 'status'
    ShowHexStatus()
  else
    echoerr "Invalid argument for :HexMode (use: on, off, toggle, status)"
  endif
enddef

def HexModeComplete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
  var candidates = ['on', 'off', 'toggle', 'status']
  if empty(arg_lead)
    return candidates
  endif
  return filter(copy(candidates), (_, val) => val =~# '^' .. arg_lead)
enddef

command! -bar HexToggle ToggleHex()
command! -bar -nargs=? -complete=customlist,HexModeComplete HexMode HexModeCmd(<q-args>)

augroup BinaryMode
  autocmd!
  execute 'autocmd BufReadPre ' .. BINARY_EXTENSIONS .. ' BinaryReadPre()'
  autocmd BufReadPost * BinaryReadPost()
  autocmd BufWritePre * BinaryWritePre()
  autocmd BufWritePost * BinaryWritePost()
augroup END
