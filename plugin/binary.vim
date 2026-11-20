vim9script
# Plugin for binary file inspection and hex editing
# Maintainer: Paul Huang

const BINARY_EXTENSIONS = '*.fd,*.fv,*.rom,*.bin,*.efi,*.exe,*.hex'

const RE_POS_INT = '^[1-9][0-9]*$'
const RE_NONNEG_INT = '^[0-9]\+$'
const RE_SIGNED_NUM = '^[+-]\?\%(0[xX][0-9a-fA-F]\+\|[0-9]\+\)$'
const RE_UNSIGNED_NUM = '^\%(0[xX][0-9a-fA-F]\+\|[0-9]\+\)$'
const RE_C_IDENT = '^[A-Za-z_][A-Za-z0-9_]*$'

def IsInHexMode(): bool
  return !!get(b:, 'in_hex_mode', false)
enddef

def EnsureXxd(): bool
  if executable('xxd') == 0
    echoerr 'xxd executable not found in PATH'
    return false
  endif
  return true
enddef

def SafeDelete(path: string): void
  if !empty(path) && !empty(getftype(path))
    delete(path)
  endif
enddef

def AddUnique(items: list<string>, value: string): void
  if index(items, value) < 0
    add(items, value)
  endif
enddef

def RunExternal(argv: list<string>): dict<any>
  if has('job') && has('channel')
    var chunks: list<string> = []
    var job = job_start(argv, {
      in_io: 'null',
      out_cb: (_, msg) => {
        add(chunks, msg)
      },
      err_cb: (_, msg) => {
        add(chunks, msg)
      },
    })
    if job_status(job) ==# 'fail'
      return {exitval: -1, out: 'Failed to execute ' .. argv[0]}
    endif
    try
      while job_status(job) ==# 'run'
        sleep 1m
      endwhile
      var ch = job_getchannel(job)
      var drain = 0
      while (ch_status(ch) ==# 'open' || ch_status(ch) ==# 'buffered') && drain < 50
        sleep 1m
        drain += 1
      endwhile
      return {exitval: job_info(job).exitval, out: join(chunks, "\n")}
    finally
      if job_status(job) ==# 'run'
        job_stop(job)
      endif
    endtry
  endif

  var cmd = join(map(copy(argv), (_, arg) => shellescape(arg)), ' ')
  var out = system(cmd)
  return {exitval: v:shell_error, out: out}
enddef

def MakeXxdSpec(
  fwd: list<string>,
  rev: list<string>,
  irrev: list<string>,
  is_plain: bool,
  err: string = ''
): dict<any>
  return {
    fwd_args: fwd,
    rev_args: rev,
    irreversible: irrev,
    is_plain: is_plain,
    error: err,
  }
enddef

def ValidateOptionValue(flag: string, val: string, pattern: string): string
  if val !~# pattern
    return printf('Invalid value for xxd option %s: %s', flag, val)
  endif
  return ''
enddef

def ParseXxdOptions(raw: any): dict<any>
  if type(raw) != v:t_string
    return MakeXxdSpec([], [], [], false, 'g:binary_xxd_options must be a string')
  endif

  var tokens = split(raw)
  var fwd: list<string> = []
  var irrev: list<string> = []
  var cols = ''
  var is_plain = false
  var i = 0

  while i < len(tokens)
    var tok = tokens[i]
    i += 1

    # Long options
    if tok ==# '-cols'
      if i >= len(tokens)
        return MakeXxdSpec([], [], [], false, 'Missing value for xxd option: -cols')
      endif
      var val = tokens[i]
      i += 1
      var err = ValidateOptionValue('-cols', val, RE_POS_INT)
      if !empty(err)
        return MakeXxdSpec([], [], [], false, err)
      endif
      extend(fwd, ['-c', val])
      cols = val
      continue
    elseif tok ==# '-ps' || tok ==# '-postscript' || tok ==# '-plain'
      add(fwd, '-p')
      is_plain = true
      continue
    elseif tok ==# '-groupsize'
      if i >= len(tokens)
        return MakeXxdSpec([], [], [], false, 'Missing value for xxd option: -groupsize')
      endif
      var val = tokens[i]
      i += 1
      var err = ValidateOptionValue('-groupsize', val, RE_NONNEG_INT)
      if !empty(err)
        return MakeXxdSpec([], [], [], false, err)
      endif
      extend(fwd, ['-g', val])
      continue
    elseif tok ==# '-bits'
      add(fwd, '-b')
      AddUnique(irrev, '-b')
      continue
    elseif tok ==# '-include'
      add(fwd, '-i')
      AddUnique(irrev, '-i')
      continue
    elseif tok ==# '-autoskip'
      add(fwd, '-a')
      AddUnique(irrev, '-a')
      continue
    elseif tok ==# '-EBCDIC'
      add(fwd, '-E')
      AddUnique(irrev, '-E')
      continue
    elseif tok ==# '-capitalize'
      add(fwd, '-C')
      AddUnique(irrev, '-C')
      continue
    elseif tok ==# '-seek' || tok ==# '-len' || tok ==# '-name'
      if i >= len(tokens)
        return MakeXxdSpec([], [], [], false, 'Missing value for xxd option: ' .. tok)
      endif
      var val = tokens[i]
      i += 1
      var short_flag = tok ==# '-seek' ? '-s' : (tok ==# '-len' ? '-l' : '-n')
      var pattern = tok ==# '-seek' ? RE_SIGNED_NUM : (tok ==# '-len' ? RE_UNSIGNED_NUM : RE_C_IDENT)
      var err = ValidateOptionValue(tok, val, pattern)
      if !empty(err)
        return MakeXxdSpec([], [], [], false, err)
      endif
      extend(fwd, [short_flag, val])
      AddUnique(irrev, short_flag)
      continue
    elseif tok ==# '-revert' || tok ==# '-version' || tok ==# '-help'
      return MakeXxdSpec([], [], [], false, 'Forbidden xxd option: ' .. tok)
    endif

    # Reject non-flags, bare '-', and double-dash tokens
    if tok[0] !=# '-' || strlen(tok) < 2 || tok[: 1] ==# '--'
      return MakeXxdSpec([], [], [], false, 'Unsupported or unsafe xxd option: ' .. tok)
    endif

    # Short options and clusters (including attached values like -c32, -g4, -s0x10)
    var j = 1
    while j < strlen(tok)
      var ch = tok[j]
      var rem = tok[j + 1 :]

      if ch ==# 'c' || ch ==# 'g' || ch ==# 's' || ch ==# 'l' || ch ==# 'o' || ch ==# 'n'
        var val = rem
        if empty(val)
          if i >= len(tokens)
            return MakeXxdSpec([], [], [], false, 'Missing value for xxd option: -' .. ch)
          endif
          val = tokens[i]
          i += 1
        endif

        var flag = '-' .. ch
        var pattern = RE_POS_INT
        if ch ==# 'g'
          pattern = RE_NONNEG_INT
        elseif ch ==# 's' || ch ==# 'o'
          pattern = RE_SIGNED_NUM
        elseif ch ==# 'l'
          pattern = RE_UNSIGNED_NUM
        elseif ch ==# 'n'
          pattern = RE_C_IDENT
        endif

        var err = ValidateOptionValue(flag, val, pattern)
        if !empty(err)
          return MakeXxdSpec([], [], [], false, err)
        endif

        extend(fwd, [flag, val])
        if ch ==# 'c'
          cols = val
        elseif ch !=# 'g'
          AddUnique(irrev, flag)
        endif
        break
      elseif ch ==# 'p'
        add(fwd, '-p')
        is_plain = true
      elseif ch ==# 'u'
        add(fwd, '-u')
      elseif ch ==# 'e' || ch ==# 'b' || ch ==# 'i' || ch ==# 'a' || ch ==# 'E' || ch ==# 'd' || ch ==# 'C'
        var flag = '-' .. ch
        add(fwd, flag)
        AddUnique(irrev, flag)
      elseif ch ==# 'r' || ch ==# 'v' || ch ==# 'h' || ch ==# 'R'
        return MakeXxdSpec([], [], [], false, 'Forbidden xxd option: -' .. ch)
      else
        return MakeXxdSpec([], [], [], false, 'Unsupported or unsafe xxd option: ' .. tok)
      endif

      j += 1
    endwhile
  endwhile

  var rev: list<string> = []
  if is_plain
    add(rev, '-p')
  elseif !empty(cols)
    extend(rev, ['-c', cols])
  endif

  return MakeXxdSpec(fwd, rev, irrev, is_plain, '')
enddef

def AssertReversible(spec: dict<any>): bool
  var spec_err: string = spec.error
  if !empty(spec_err)
    echoerr spec_err
    return false
  endif
  var irrev: list<string> = spec.irreversible
  if !empty(irrev)
    echoerr 'Cannot convert or write binary: irreversible xxd option(s) active (' .. join(irrev, ', ') .. ')'
    return false
  endif
  return true
enddef

def IsEmptyLines(lines: list<string>): bool
  for line in lines
    if !empty(trim(line))
      return false
    endif
  endfor
  return true
enddef

def ValidateHexLines(lines: list<string>, is_plain: bool): string
  if IsEmptyLines(lines)
    return ''
  endif

  if is_plain
    var total_nibbles = 0
    for idx in range(len(lines))
      var stripped = substitute(lines[idx], '\s\+', '', 'g')
      if empty(stripped)
        continue
      endif
      if stripped !~# '^[0-9a-fA-F]\+$'
        return printf('Invalid plain hex on line %d', idx + 1)
      endif
      total_nibbles += strlen(stripped)
    endfor
    if total_nibbles == 0 || (total_nibbles % 2) != 0
      return 'Invalid plain hex: odd or zero number of hex digits'
    endif
    return ''
  endif

  var valid_lines = 0
  for idx in range(len(lines))
    var line = lines[idx]
    if empty(trim(line))
      continue
    endif
    var colon_idx = stridx(line, ':')
    if colon_idx <= 0
      return printf('Invalid hex dump on line %d (missing address prefix)', idx + 1)
    endif
    var addr_part = trim(line[: colon_idx - 1])
    if addr_part !~# '^[0-9a-fA-F]\+$'
      return printf('Invalid hex address on line %d', idx + 1)
    endif
    var after_colon = line[colon_idx + 1 :]
    if after_colon !~# '^\s\+'
      return printf('Invalid hex dump on line %d (missing space after address)', idx + 1)
    endif
    var trimmed_after = substitute(after_colon, '^\s\+', '', '')
    var hex_section = split(trimmed_after, '  ', true)[0]
    var hex_digits = substitute(hex_section, ' ', '', 'g')
    if empty(hex_digits) || hex_digits !~# '^[0-9a-fA-F]\+$' || (strlen(hex_digits) % 2) != 0
      return printf('Invalid hex bytes on line %d', idx + 1)
    endif
    valid_lines += 1
  endfor

  if valid_lines == 0
    return 'No valid hex dump lines found'
  endif
  return ''
enddef

def ReplaceBufferLines(lines: list<string>): void
  var target = empty(lines) ? [''] : lines
  silent setline(1, target)
  var cur_last = line('$')
  if cur_last > len(target)
    silent deletebufline('%', len(target) + 1, '$')
  endif
enddef

def RunXxdForward(in_file: string, fwd_args: list<string>): dict<any>
  var tmp_out = tempname()
  var result: dict<any> = {ok: false, lines: []}
  try
    var cmd: list<string> = ['xxd'] + fwd_args + [in_file, tmp_out]
    var res = RunExternal(cmd)
    if res.exitval != 0
      echoerr printf('xxd forward conversion failed (exit %d): %s', res.exitval, trim(res.out))
      return result
    endif
    var raw_lines = readfile(tmp_out)
    var cleaned = map(raw_lines, (_, line) => substitute(line, '\r$', '', ''))
    result = {ok: true, lines: empty(cleaned) ? [''] : cleaned}
  finally
    SafeDelete(tmp_out)
  endtry
  return result
enddef

def HexLinesToFile(hex_lines: list<string>, spec: dict<any>, out_file: string): dict<any>
  if !AssertReversible(spec)
    return {ok: false, data: 0z}
  endif

  if IsEmptyLines(hex_lines)
    writefile(0z, out_file)
    return {ok: true, data: 0z}
  endif

  var is_plain: bool = spec.is_plain
  var val_err = ValidateHexLines(hex_lines, is_plain)
  if !empty(val_err)
    echoerr 'Binary conversion aborted: ' .. val_err
    return {ok: false, data: 0z}
  endif

  var tmp_in = tempname()
  var result: dict<any> = {ok: false, data: 0z}
  try
    writefile(hex_lines, tmp_in)
    var rev_args: list<string> = spec.rev_args
    var cmd: list<string> = ['xxd', '-r'] + rev_args + [tmp_in, out_file]
    var res = RunExternal(cmd)
    if res.exitval != 0
      echoerr printf('xxd reverse conversion failed (exit %d): %s', res.exitval, trim(res.out))
      return result
    endif

    var raw_blob = readblob(out_file)
    if len(raw_blob) == 0
      echoerr 'Binary conversion aborted: xxd -r produced 0 bytes from non-empty hex input'
      return result
    endif
    result = {ok: true, data: raw_blob}
  finally
    SafeDelete(tmp_in)
  endtry
  return result
enddef

def NormalizePath(path: string): string
  var p = fnamemodify(path, ':p')
  if has('win32')
    p = substitute(p, '/', '\\', 'g')
  endif
  p = simplify(resolve(p))
  if has('win32')
    p = substitute(p, '/', '\\', 'g')
  endif
  return p
enddef

def IsSameFile(path_a: string, path_b: string): bool
  if empty(path_a) || empty(path_b)
    return false
  endif
  var norm_a = NormalizePath(path_a)
  var norm_b = NormalizePath(path_b)
  return has('fname_case') ? (norm_a ==# norm_b) : (norm_a ==? norm_b)
enddef

def SyncBufferMtime(): void
  augroup BinarySyncMtime
    autocmd!
    autocmd FileChangedShell <buffer> v:fcs_choice = ''
  augroup END
  try
    execute 'silent checktime ' .. bufnr('%')
  finally
    augroup BinarySyncMtime
      autocmd!
    augroup END
  endtry
enddef

def RegisterWriteCmd(): void
  augroup BinaryModeWrite
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> BinaryWriteCmd(expand('<afile>'), v:cmdbang)
    autocmd FileWriteCmd <buffer> BinaryWriteCmd(expand('<afile>'), v:cmdbang)
    autocmd FileAppendCmd <buffer> BinaryWriteCmd(expand('<afile>'), v:cmdbang, true)
  augroup END
enddef

def UnregisterWriteCmd(): void
  augroup BinaryModeWrite
    autocmd! * <buffer>
  augroup END
enddef

def RestoreOriginalOptions(): void
  if has_key(b:, 'binary_orig_bin')
    &l:binary = b:binary_orig_bin
  else
    &l:binary = false
  endif
  if has_key(b:, 'binary_orig_fixeol')
    &l:fixendofline = b:binary_orig_fixeol
  endif
  if has_key(b:, 'binary_orig_ff') && !empty(b:binary_orig_ff)
    &l:fileformat = b:binary_orig_ff
  endif
  if has_key(b:, 'binary_orig_ft')
    &l:filetype = b:binary_orig_ft
  endif
  for key in ['binary_orig_ft', 'binary_orig_bin', 'binary_orig_ff', 'binary_orig_fixeol']
    if has_key(b:, key)
      remove(b:, key)
    endif
  endfor
enddef

def BinaryReadPreReset(): void
  if !IsInHexMode()
    return
  endif
  UnregisterWriteCmd()
  RestoreOriginalOptions()
  b:in_hex_mode = false
  for key in ['binary_xxd_spec', 'binary_view']
    if has_key(b:, key)
      remove(b:, key)
    endif
  endfor
enddef

def BinaryReadPre(): void
  &l:binary = true
  &l:fixendofline = false
  &l:fileformat = 'unix'
enddef

def ConvertToHex(reset_undo: bool = false): void
  if IsInHexMode()
    return
  endif
  if !EnsureXxd()
    return
  endif
  if !&l:modifiable
    echoerr "E21: Cannot make changes, 'modifiable' is off"
    return
  endif

  var spec = ParseXxdOptions(get(g:, 'binary_xxd_options', ''))
  var spec_err: string = spec.error
  if !empty(spec_err)
    echoerr spec_err
    return
  endif

  var was_modified = &l:modified
  var orig_bin = &l:binary
  var orig_eol = &l:endofline
  var orig_fixeol = &l:fixendofline

  var tmp_in = tempname()
  try
    var raw_lines = getline(1, '$')
    var is_single_empty = len(raw_lines) == 1 && empty(raw_lines[0])
    if orig_bin
      if orig_eol && (!is_single_empty || wordcount().bytes > 0)
        add(raw_lines, '')
      endif
    else
      if (orig_eol || orig_fixeol) && (!is_single_empty || wordcount().bytes > 0)
        add(raw_lines, '')
      endif
    endif
    writefile(raw_lines, tmp_in, 'b')

    var fwd_args: list<string> = spec.fwd_args
    var fwd_res = RunXxdForward(tmp_in, fwd_args)
    if !fwd_res.ok
      return
    endif
    var hex_lines: list<string> = fwd_res.lines

    if !has_key(b:, 'binary_orig_ft')
      b:binary_orig_ft = &l:filetype
      b:binary_orig_bin = &l:binary
      b:binary_orig_ff = &l:fileformat
      b:binary_orig_fixeol = &l:fixendofline
    endif

    &l:binary = true
    &l:fixendofline = false
    &l:fileformat = 'unix'

    if reset_undo
      var saved_ul = &l:undolevels
      try
        &l:undolevels = -1
        ReplaceBufferLines(hex_lines)
      finally
        &l:undolevels = saved_ul
      endtry
    else
      ReplaceBufferLines(hex_lines)
    endif

    &l:filetype = 'xxd'
    if !was_modified
      &l:modified = false
    endif
    b:binary_xxd_spec = spec
    b:in_hex_mode = true
    RegisterWriteCmd()
    redraw
  finally
    SafeDelete(tmp_in)
  endtry
enddef

def ConvertToBinary(): void
  if !IsInHexMode()
    return
  endif
  if !EnsureXxd()
    return
  endif
  if !&l:modifiable
    echoerr "E21: Cannot make changes, 'modifiable' is off"
    return
  endif

  var spec: dict<any> = get(b:, 'binary_xxd_spec', ParseXxdOptions(get(g:, 'binary_xxd_options', '')))
  var was_modified = &l:modified
  var tmp_bin = tempname()
  try
    var rev_res = HexLinesToFile(getline(1, '$'), spec, tmp_bin)
    if !rev_res.ok
      return
    endif
    var raw_blob: blob = rev_res.data
    if len(raw_blob) == 0
      ReplaceBufferLines([''])
      &l:endofline = false
    else
      var bin_lines = readfile(tmp_bin, 'b')
      var has_nl = len(bin_lines) >= 2 && empty(bin_lines[-1])
      if has_nl
        remove(bin_lines, -1)
      endif
      ReplaceBufferLines(bin_lines)
      &l:endofline = has_nl
    endif

    UnregisterWriteCmd()
    RestoreOriginalOptions()
    if !was_modified
      &l:modified = false
    endif
    b:in_hex_mode = false
    if has_key(b:, 'binary_xxd_spec')
      remove(b:, 'binary_xxd_spec')
    endif
    redraw
  finally
    SafeDelete(tmp_bin)
  endtry
enddef

def BinaryBufNew(): void
  if str2nr(expand('<abuf>')) == bufnr('%') && IsInHexMode()
    RegisterWriteCmd()
  endif
enddef

def BinaryReadPost(): void
  if &l:binary && !IsInHexMode()
    ConvertToHex(true)
  endif
enddef

def BinaryWriteCmd(target_arg: string, bang: number, is_append: bool = false): void
  if !EnsureXxd()
    return
  endif
  if empty(target_arg)
    echoerr 'E32: No file name'
    return
  endif

  var target_file = fnamemodify(target_arg, ':p')
  var buf_file = empty(expand('%')) ? '' : expand('%:p')
  var is_same_file = IsSameFile(target_file, buf_file)
  var target_type = getftype(target_file)

  if target_type ==# 'dir'
    echoerr 'E17: "' .. target_file .. '" is a directory'
    return
  endif
  if is_same_file && &l:readonly && bang == 0
    echoerr "E45: 'readonly' option is set (add ! to override)"
    return
  endif
  if !is_append && !is_same_file && !empty(target_type) && bang == 0
    echoerr 'E13: File exists (add ! to override)'
    return
  endif
  if bang == 0 && (target_type ==# 'file' || target_type ==# 'link') && filewritable(target_file) == 0
    echoerr 'E505: "' .. target_file .. '" is read-only (add ! to override)'
    return
  endif

  var start_line = line("'[")
  var end_line = line("']")
  if start_line <= 0 || end_line <= 0 || start_line > end_line
    start_line = 1
    end_line = line('$')
  endif
  var is_full_buffer = (start_line == 1 && end_line == line('$'))
  var update_current_buf = !is_append && is_same_file && is_full_buffer
  var lines = getline(start_line, end_line)

  var spec: dict<any> = get(b:, 'binary_xxd_spec', ParseXxdOptions(get(g:, 'binary_xxd_options', '')))
  var tmp_bin = tempname()
  b:binary_view = winsaveview()

  try
    var rev_res = HexLinesToFile(lines, spec, tmp_bin)
    if !rev_res.ok
      return
    endif
    var raw_blob: blob = rev_res.data

    var orig_perm = ''
    var changed_perm = false
    if bang != 0 && (target_type ==# 'file' || target_type ==# 'link') && filewritable(target_file) == 0
      orig_perm = getfperm(target_file)
      if strlen(orig_perm) >= 2 && orig_perm[1] !=# 'w'
        if setfperm(target_file, orig_perm[0] .. 'w' .. orig_perm[2 :]) != 0
          changed_perm = true
        endif
      endif
    endif

    try
      writefile(raw_blob, target_file, is_append ? 'a' : '')
    finally
      if changed_perm && !empty(orig_perm)
        setfperm(target_file, orig_perm)
      endif
    endtry

    if update_current_buf
      var fwd_args: list<string> = spec.fwd_args
      if len(raw_blob) == 0
        if lines !=# [''] && &l:modifiable
          try
            undojoin
          catch /^Vim\%((\a\+)\)\=:E790:/
          endtry
          ReplaceBufferLines([''])
        endif
      else
        var fwd_res = RunXxdForward(tmp_bin, fwd_args)
        if fwd_res.ok && fwd_res.lines !=# lines && &l:modifiable
          try
            undojoin
          catch /^Vim\%((\a\+)\)\=:E790:/
          endtry
          ReplaceBufferLines(fwd_res.lines)
        endif
      endif
      &l:modified = false
      if bang != 0 && &l:readonly && !changed_perm
        &l:readonly = false
      endif
      SyncBufferMtime()
    endif
  finally
    if has_key(b:, 'binary_view')
      winrestview(b:binary_view)
      remove(b:, 'binary_view')
    endif
    SafeDelete(tmp_bin)
  endtry
  redraw
enddef

def ToggleHex(): void
  if IsInHexMode()
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
  if IsInHexMode()
    echo 'Hex mode: ON'
  else
    echo 'Hex mode: OFF'
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
    echoerr 'Invalid argument for :HexMode (use: on, off, toggle, status)'
  endif
enddef

def HexModeComplete(arg_lead: string, _cmd_line: string, _cursor_pos: number): list<string>
  const candidates = ['on', 'off', 'toggle', 'status']
  if empty(arg_lead)
    return copy(candidates)
  endif
  var prefix = tolower(arg_lead)
  return filter(copy(candidates), (_, val) => stridx(val, prefix) == 0)
enddef

command! -bar HexToggle ToggleHex()
command! -bar -nargs=? -complete=customlist,HexModeComplete HexMode HexModeCmd(<q-args>)

augroup BinaryModeWrite
augroup END

augroup BinaryMode
  autocmd!
  autocmd BufNew * BinaryBufNew()
  autocmd BufReadPre * BinaryReadPreReset()
  execute 'autocmd BufReadPre ' .. BINARY_EXTENSIONS .. ' BinaryReadPre()'
  autocmd BufReadPost * BinaryReadPost()
augroup END
