vim9script
# Safe split-preserving buffer deletion compatible with 'nohidden'
# Maintainer: Paul Huang

def NormalizeSlashes(path: string): string
  return has('win32') ? substitute(path, '/', '\\', 'g') : path
enddef

def NormalizePath(path: string): string
  return NormalizeSlashes(simplify(fnamemodify(path, ':p')))
enddef

def PathsEqual(a: string, b: string): bool
  return has('fname_case') != 0 ? (a ==# b) : (a ==? b)
enddef

def MatchBuffersInSet(query: string, infos: list<dict<any>>): list<number>
  var q_slash = NormalizeSlashes(query)
  var q_norm = NormalizePath(query)
  var case_sens = has('fname_case') != 0
  var q_cmp = case_sens ? q_slash : tolower(q_slash)

  var exact_matches: list<number> = []
  var tail_matches: list<number> = []
  var partial_matches: list<number> = []

  for info in infos
    var name: string = info.name
    if empty(name)
      continue
    endif
    var n_slash = NormalizeSlashes(name)
    if PathsEqual(n_slash, q_slash) || PathsEqual(NormalizePath(name), q_norm)
      add(exact_matches, info.bufnr)
    elseif PathsEqual(fnamemodify(n_slash, ':t'), q_slash)
      add(tail_matches, info.bufnr)
    else
      var hay = case_sens ? n_slash : tolower(n_slash)
      if stridx(hay, q_cmp) >= 0
        add(partial_matches, info.bufnr)
      endif
    endif
  endfor

  if !empty(exact_matches)
    return exact_matches
  elseif !empty(tail_matches)
    return tail_matches
  endif
  return partial_matches
enddef

def ResolveTargetBuf(raw_arg: string): number
  var arg = trim(raw_arg)
  if empty(arg) || arg ==# '%'
    return bufnr('%')
  endif

  if arg ==# '#'
    var alt = bufnr('#')
    if alt <= 0 || bufexists(alt) == 0
      echoerr "E194: No alternate file name to substitute for '#'"
      return -1
    endif
    return alt
  endif

  if arg =~# '^\d\+$'
    var nr = str2nr(arg)
    if nr <= 0 || bufexists(nr) == 0
      echoerr printf('E86: Buffer %d does not exist', nr)
      return -1
    endif
    return nr
  endif

  var active_infos: list<dict<any>> = []
  var inactive_infos: list<dict<any>> = []
  for info in getbufinfo()
    if info.listed != 0 || info.loaded != 0
      add(active_infos, info)
    else
      add(inactive_infos, info)
    endif
  endfor

  # Try raw argument first, then completion-unescaped (e.g. '\ ' from -complete=buffer)
  var queries: list<string> = [arg]
  var unescaped = substitute(arg, '\\\([ #%$]\)', '\1', 'g')
  if unescaped !=# arg
    add(queries, unescaped)
  endif

  for info_set in [active_infos, inactive_infos]
    for query in queries
      var matches = MatchBuffersInSet(query, info_set)
      if len(matches) == 1
        return matches[0]
      elseif len(matches) > 1
        echoerr printf('E93: More than one match for %s', arg)
        return -1
      endif
    endfor
  endfor

  echoerr printf('E94: No matching buffer for %s', arg)
  return -1
enddef

def IsRunningTerminal(buf: number): bool
  if getbufvar(buf, '&buftype', '') !=# 'terminal'
    return false
  endif
  if !exists('*term_getstatus')
    return false
  endif
  var status: string = call('term_getstatus', [buf])
  return stridx(status, 'running') >= 0
enddef

def IsModifiedWriteable(buf: number): bool
  var bt: string = getbufvar(buf, '&buftype', '')
  if bt !=# '' && bt !=# 'acwrite'
    return false
  endif
  return !empty(getbufvar(buf, '&modified', 0))
enddef

def GetOtherListedBufs(target_buf: number): list<number>
  var others: list<number> = []
  for info in getbufinfo({buflisted: 1})
    var nr: number = info.bufnr
    if nr != target_buf
      add(others, nr)
    endif
  endfor
  sort(others, 'n')
  return others
enddef

def IsSoleEmptyUnnamedBuffer(buf: number, listed_others: list<number>): bool
  if !empty(listed_others)
    return false
  endif
  if buflisted(buf) == 0 || !empty(bufname(buf))
    return false
  endif
  if !empty(getbufvar(buf, '&buftype', ''))
    return false
  endif
  if !empty(getbufvar(buf, '&modified', 0))
    return false
  endif
  var lines = getbufline(buf, 1, 2)
  return empty(lines) || (len(lines) == 1 && empty(lines[0]))
enddef

def PickReplacementBuf(target_buf: number, listed_others: list<number>): number
  var alt = bufnr('#')
  if alt > 0 && alt != target_buf && bufexists(alt) != 0 && buflisted(alt) != 0
    return alt
  endif
  if empty(listed_others)
    return -1
  endif
  var prev = -1
  for nr in listed_others
    if nr < target_buf
      prev = nr
    else
      break
    endif
  endfor
  return prev > 0 ? prev : listed_others[0]
enddef

def GetTargetWindows(target_buf: number): list<number>
  var wins: list<number> = []
  for winid in win_findbuf(target_buf)
    var wtype = win_gettype(winid)
    if wtype !=# 'popup' && wtype !=# 'command'
      add(wins, winid)
    endif
  endfor
  return wins
enddef

def BdeleteCmd(bang: bool, raw_arg: string): void
  if win_gettype() ==# 'command'
    echoerr 'E11: Invalid in command-line window'
    return
  endif

  var target_buf = ResolveTargetBuf(raw_arg)
  if target_buf <= 0
    return
  endif

  var bt: string = getbufvar(target_buf, '&buftype', '')
  if bt ==# 'quickfix'
    echoerr 'Bdelete: cannot delete quickfix/loclist buffer (use :cclose or :lclose)'
    return
  endif
  if bt ==# 'popup'
    echoerr 'Bdelete: cannot delete popup buffer'
    return
  endif

  if !bang
    if IsRunningTerminal(target_buf)
      echoerr printf('E948: Job still running in buffer %d (add ! to override)', target_buf)
      return
    endif
    if IsModifiedWriteable(target_buf)
      echoerr printf('E89: No write since last change for buffer %d (add ! to override)', target_buf)
      return
    endif
  endif

  var listed_others = GetOtherListedBufs(target_buf)
  if IsSoleEmptyUnnamedBuffer(target_buf, listed_others)
    return
  endif

  var target_wins = GetTargetWindows(target_buf)
  if !empty(target_wins)
    if !bang && exists('+winfixbuf')
      for winid in target_wins
        if !empty(getwinvar(winid, '&winfixbuf', 0))
          echoerr "E1513: Cannot switch buffer. 'winfixbuf' is enabled (add ! to override)"
          return
        endif
      endfor
    endif

    var orig_winid = win_getid()
    var orig_tabnr = tabpagenr()
    var fallback_buf = -1
    try
      for winid in target_wins
        if win_gotoid(winid) == 0
          continue
        endif
        if bufnr('%') != target_buf
          continue
        endif
        var repl = PickReplacementBuf(target_buf, listed_others)
        if repl > 0
          execute (bang ? 'hide buffer! ' : 'hide buffer ') .. repl
        elseif fallback_buf > 0 && bufexists(fallback_buf) != 0
          execute (bang ? 'hide buffer! ' : 'hide buffer ') .. fallback_buf
        else
          execute bang ? 'hide enew!' : 'hide enew'
          setlocal buflisted
          fallback_buf = bufnr('%')
        endif
      endfor
    finally
      if win_gotoid(orig_winid) == 0 && tabpagenr() != orig_tabnr && orig_tabnr <= tabpagenr('$')
        execute 'tabnext ' .. orig_tabnr
      endif
    endtry
  endif

  # Abort deletion if any switchable window still displays target_buf (e.g. 'winfixbuf')
  if !empty(GetTargetWindows(target_buf))
    return
  endif

  if bufexists(target_buf) != 0 && (buflisted(target_buf) != 0 || bufloaded(target_buf) != 0)
    execute (bang ? 'bdelete! ' : 'bdelete ') .. target_buf
  endif
enddef

command! -bang -bar -nargs=? -complete=buffer Bdelete BdeleteCmd(<q-bang> ==# '!', <q-args>)
