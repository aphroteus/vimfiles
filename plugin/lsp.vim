vim9script

var lspOpts = {
    autoHighlightDiags: true,
    showSignature: true,
    omniComplete: true,
}

var lspServers = [
    {
        name: 'clangd',
        filetype: ['c'],
        path: 'clangd',
        args: [
            '--background-index',
            # '--clang-tidy',
            '--header-insertion=never',
            '--pch-storage=memory',
        ]
    }
]

autocmd User LspSetup {
    call LspOptionsSet(lspOpts)
    call LspAddServer(lspServers)
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
