# vimfiles
My vimrc configuration

## Prerequisites

Available in `PATH` environment variable:

*   [Git](https://git-scm.com/)
*   [ripgrep](https://github.com/BurntSushi/ripgrep) (May put in `$HOME\bin\` or `%UserProfile%/bin/` if not availible
    in `PATH`)

Font:
*   [Inconsolata for Powerline](https://github.com/powerline/fonts/tree/master/Inconsolata)

## Installing on Windows

    cd /d %UserProfile%
    git clone https://github.com/aphroteus/vimfiles.git
Open vim or gVim, and run `:PluginInstall`\
After install procedure complete, restart vim to take effect

## Installing on Linux

    cd ~/
    git clone https://github.com/aphroteus/vimfiles.git
    mv ./vimfiles ./.vim
Open vim or gVim, and run `:PluginInstall`\
After install procedure complete, restart vim to take effect

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

