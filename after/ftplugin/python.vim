setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4
setlocal textwidth=79
setlocal expandtab
setlocal autoindent
setlocal fileformat=unix

let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin .. ' | ' : '')
      \ .. 'setlocal tabstop< softtabstop< shiftwidth< textwidth< expandtab< autoindent< fileformat<'
