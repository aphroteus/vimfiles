vim9script

var lspOpts: dict<any> = {
  autoHighlightDiags: true,
  showSignature: true,
  omniComplete: true,
}

var packadd_attempted = false

def SetupLsp(): void
  g:LspOptionsSet(lspOpts)
  if executable('clangd') != 0
    g:LspAddServer([
      {
        name: 'clangd',
        filetype: ['c', 'cpp'],
        path: 'clangd',
        args: [
          '--background-index',
          # '--clang-tidy',
          '--header-insertion=never',
          '--pch-storage=memory',
        ],
      },
    ])
  endif
enddef

def MaybeLoadLsp(): void
  if get(g:, 'loaded_lsp', false) || packadd_attempted || executable('clangd') == 0
    return
  endif
  packadd_attempted = true
  try
    packadd lsp
  catch /^Vim\%((\a\+)\)\=:E919:/
  endtry
enddef

augroup LspConfig
  autocmd!
  autocmd FileType c,cpp MaybeLoadLsp()
  autocmd User LspSetup SetupLsp()
  autocmd User LspAttached {
    nnoremap <buffer> gd <Cmd>LspGotoDefinition<CR>
    nnoremap <buffer> gi <Cmd>LspGotoImpl<CR>
    nnoremap <buffer> K  <Cmd>LspHover<CR>
    nnoremap <buffer> <leader>ca <Cmd>LspCodeAction<CR>
    nnoremap <buffer> <leader>f  <Cmd>LspFormat<CR>
    nnoremap <buffer> [d <Cmd>LspDiag prev<CR>
    nnoremap <buffer> ]d <Cmd>LspDiag next<CR>
  }
augroup END

if get(g:, 'loaded_lsp', false) && exists('*g:LspOptionsSet')
  SetupLsp()
endif
