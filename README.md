# vimfiles
My vimrc

## Prerequisites

Available in PATH environment variable:

*   [Git](https://git-scm.com/)
*   [ripgrep](https://github.com/BurntSushi/ripgrep): put in `$HOME\bin\` or `%UserProfile%/bin/`

## Installing on Windows

    cd /d %UserProfile%
    git clone https://github.com/aphroteus/vimfiles.git
Open vim or gVim and run `:PluginInstall`

## Installing on Linux

    cd ~/
    git clone https://github.com/aphroteus/vimfiles.git
    mv ./vimfiles ./.vim
Open vim and run `:PluginInstall`

## Usage

Hotkeys in normal mode:

1. Search cursor focused keyword:
    *   Move the cursor on keyword, then press `<F2>`

2. Search input keyword or string:
    *   Press `<F3> + keyword + <CR>`
    *   Press `<F3> + "the string" + <CR>`

3. Switch between the buffers:
    *   Press `gb` to previous buffer
    *   Press `gn` to next buffer
    *   Press `bd` to close current buffer

