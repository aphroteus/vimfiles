vim9script

# Set window-local current working directory to project root or file directory
def SetCwd(): void
  if empty(expand('%')) || &buftype !=# ''
    return
  endif

  var cph = expand('%:p:h')
  if cph =~ '^.\+://'
    return
  endif

  var target = ''
  if exists('b:project_root')
    target = b:project_root
  else
    var curr = cph
    var wd = ''
    while true
      if isdirectory(curr .. '/.git')
          || filereadable(curr .. '/.git')
          || isdirectory(curr .. '/.repo')
          || isdirectory(curr .. '/.hg')
          || isdirectory(curr .. '/.svn')
          || isdirectory(curr .. '/.bzr')
          || isdirectory(curr .. '/_darcs')
          || filereadable(curr .. '/.vimprojects')
        wd = curr
      endif
      var parent = fnamemodify(curr, ':h')
      if parent == curr
        break
      endif
      curr = parent
    endwhile

    target = (wd == '' ? cph : wd)
    b:project_root = target
  endif

  if target == '' || !isdirectory(target)
    return
  endif

  if &autochdir
    &autochdir = false
  endif

  if getcwd() != target
    execute 'lcd!' fnameescape(target)
  endif
enddef

augroup AutoSetCwd
  autocmd!
  autocmd BufEnter * SetCwd()
augroup END
