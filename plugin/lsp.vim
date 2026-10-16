vim9script

var lspOpts: dict<any> = {
  autoHighlightDiags: true,
  showSignature: true,
  omniComplete: true,
}

var lspServers: list<dict<any>> = []
if executable('clangd')
  lspServers->add({
    name: 'clangd',
    filetype: ['c', 'cpp'],
    path: 'clangd',
    args: [
      '--background-index',
      # '--clang-tidy',
      '--header-insertion=never',
      '--pch-storage=memory',
    ],
  })
endif

augroup LspConfig
  autocmd!
  autocmd User LspSetup {
    g:LspOptionsSet(lspOpts)
    if !empty(lspServers)
      g:LspAddServer(lspServers)
    endif
  }

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
