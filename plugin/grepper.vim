vim9script
# Lazy-loading configuration, stubs, and airline integration for vim-grepper

const DEFAULT_TOOLS: list<string> = ['rg', 'git', 'findstr', 'grep']
const RG_GREPPRG: string = 'rg -H --no-heading --vimgrep --smart-case'

if v:vim_did_enter == 0
  if exists('g:airline_section_x')
    g:airline_section_x_user_customized = true
  else
    unlet! g:airline_section_x_user_customized
  endif
endif

var in_lazy_cmd: bool = false

def FilterExecutableTools(cfg: dict<any>, candidates: list<string>): list<string>
  var result: list<string> = []
  for tool in candidates
    if has_key(cfg, tool)
        && type(cfg[tool]) == v:t_dict
        && has_key(cfg[tool], 'grepprg')
        && executable(expand(matchstr(cfg[tool].grepprg, '^[^ ]*'))) != 0
      add(result, tool)
    endif
  endfor
  return result
enddef

def ConfigureGrepper(): void
  var cfg: dict<any> = exists('g:grepper') && type(g:grepper) == v:t_dict ? g:grepper : {}
  var rg_cfg: dict<any> = has_key(cfg, 'rg') && type(cfg.rg) == v:t_dict ? cfg.rg : {}
  rg_cfg.grepprg = RG_GREPPRG
  cfg.rg = rg_cfg
  cfg.highlight = 1
  cfg.open = 0

  if get(g:, 'loaded_grepper', 0) != 0
    cfg.tools = FilterExecutableTools(cfg, DEFAULT_TOOLS)
    if has_key(cfg, 'operator') && type(cfg.operator) == v:t_dict
      var op_rg: dict<any> = has_key(cfg.operator, 'rg') && type(cfg.operator.rg) == v:t_dict
        ? cfg.operator.rg
        : {}
      op_rg.grepprg = RG_GREPPRG
      cfg.operator.rg = op_rg
      cfg.operator.highlight = 1
      cfg.operator.open = 0
      cfg.operator.tools = copy(cfg.tools)
    endif
  else
    cfg.tools = copy(DEFAULT_TOOLS)
  endif

  g:grepper = cfg
enddef

def InsertGrepperExt(exts: list<any>): void
  if index(exts, 'grepper') >= 0
    return
  endif
  var sc_idx: number = index(exts, 'searchcount')
  if sc_idx >= 0
    insert(exts, 'grepper', sc_idx)
  else
    add(exts, 'grepper')
  endif
enddef

def AttachAirlineGrepper(): void
  if get(g:, 'loaded_grepper', 0) == 0
    return
  endif

  if exists('g:airline_extensions') && type(g:airline_extensions) == v:t_list
    InsertGrepperExt(g:airline_extensions)
  endif

  if get(g:, 'loaded_airline', 0) != 0 && exists('g:airline_section_x')
    var loaded: list<any> = airline#extensions#get_loaded_extensions()
    if index(loaded, 'grepper') < 0
      airline#extensions#grepper#init({})
      InsertGrepperExt(loaded)
    endif

    if !get(g:, 'airline_section_x_user_customized', false)
        && type(g:airline_section_x) == v:t_string
        && stridx(g:airline_section_x, 'airline#extensions#grepper#status') < 0
      unlet g:airline_section_x
      airline#init#sections()
      airline#update_statusline()
    endif
  endif
enddef

def NoopOperator(_type: string): void
enddef

def EnsureLoaded(quiet: bool = false): bool
  if get(g:, 'loaded_grepper', 0) != 0 && exists('*g:GrepperOperator')
    return true
  endif
  try
    packadd vim-grepper
  catch /^Vim\%((\a\+)\)\=:E919:/
    if !quiet
      echohl ErrorMsg
      unsilent echomsg 'vim-grepper: package not found in pack/*/opt/vim-grepper (E919)'
      echohl NONE
    endif
    return false
  endtry
  if get(g:, 'loaded_grepper', 0) == 0 || !exists('*g:GrepperOperator')
    if !quiet
      echohl ErrorMsg
      unsilent echomsg 'vim-grepper: package failed to initialize'
      echohl NONE
    endif
    return false
  endif
  AttachAirlineGrepper()
  return true
enddef

def GrepperComplete(lead: string, line: string, pos: number): list<string>
  if !EnsureLoaded(true) || !exists('*grepper#complete')
    return []
  endif
  var res: any = call('grepper#complete', [lead, line, pos])
  return type(res) == v:t_list ? res : []
enddef

def LazyGrepperCmd(args: string): void
  if in_lazy_cmd
    echohl ErrorMsg
    unsilent echomsg 'vim-grepper: command stub was not replaced by upstream :Grepper'
    echohl NONE
    return
  endif
  if !EnsureLoaded()
    return
  endif
  in_lazy_cmd = true
  try
    execute 'Grepper' .. (empty(args) ? '' : ' ' .. args)
  finally
    in_lazy_cmd = false
  endtry
enddef

def LazyNormalOp(): void
  if EnsureLoaded()
    &operatorfunc = 'GrepperOperator'
  else
    &operatorfunc = NoopOperator
  endif
enddef

def LazyVisualOp(): void
  if EnsureLoaded()
    g:GrepperOperator(visualmode())
  endif
enddef

ConfigureGrepper()

augroup GrepperCopen
  autocmd!
  autocmd User Grepper copen
augroup END

augroup GrepperConfig
  autocmd!
  autocmd SourcePost */vim-grepper/plugin/grepper.vim AttachAirlineGrepper()
augroup END

if get(g:, 'loaded_grepper', 0) == 0
  nnoremap <silent> <Plug>(GrepperOperator) <ScriptCmd>LazyNormalOp()<CR>g@
  xnoremap <silent> <Plug>(GrepperOperator) <Esc><ScriptCmd>LazyVisualOp()<CR>
  command! -nargs=* -complete=customlist,GrepperComplete Grepper LazyGrepperCmd(<q-args>)
endif

nmap gs <Plug>(GrepperOperator)
xmap gs <Plug>(GrepperOperator)
nnoremap <F2> <Cmd>Grepper -cword -noprompt<CR>
nnoremap <F3> <Cmd>Grepper<CR>

if get(g:, 'loaded_grepper', 0) != 0
  AttachAirlineGrepper()
endif
