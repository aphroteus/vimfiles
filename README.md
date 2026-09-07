# vimfiles
My vimrc configuration

## Prerequisites

Utility available in `PATH` environment variable:

*   [Git](https://git-scm.com/)
*   [ripgrep](https://github.com/BurntSushi/ripgrep)

Font Installed:
*   [Inconsolata for Powerline](https://github.com/powerline/fonts/tree/master/Inconsolata)

## Installation Instructions
### On Windows

    winget install Git.Git
    winget install BurntSushi.ripgrep.MSVC
    git clone --recursive https://github.com/aphroteus/vimfiles.git %UserProfile%\vimfiles

### On Linux

    git clone --recursive https://github.com/aphroteus/vimfiles.git ~/.vim

## Usage

Hotkeys in normal mode:

1. Search cursor focused keyword:
    *   Move the cursor on keyword, then press `<F2>`

2. Search input keyword or string:
    *   Press `<F3> + keyword + <CR>`
    *   Press `<F3> + "the string" + <CR>`

3. Switch between the buffers:
    *   Press `[b` to previous buffer
    *   Press `]b` to next buffer
    *   Press `<Leader>bd` to close current buffer without closing split window

4. Configuration file management:
    *   Press `<Leader>ev` to edit vimrc
    *   Press `<Leader>sv` to reload vimrc in place

5. Clipboard operations:

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal | `<C-v>` | Paste from clipboard (cursor placed at end of paste) |
| Normal | `<C-q>` | Enter Visual Block mode |
| Normal | `cs` | Copy relative file path to clipboard |
| Visual | `<C-c>` | Copy selection to clipboard |
| Visual | `<C-x>` | Cut selection to clipboard |
| Visual | `<C-v>` | Paste / replace selection with clipboard content |
| Insert | `<C-v>` | Paste from clipboard (preserves indentation, creates undo boundary) |
| Command-line | `<C-v>` | Paste from clipboard into command line |


