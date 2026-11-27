# vimfiles

Cross-platform (`Windows`, `Linux`, `Cygwin`) modular Vim configuration written in native `vim9script`. It features on-demand lazy-loaded C/C++ LSP integration and asynchronous project search, UEFI/EDK II syntax highlighting, lossless `xxd`-backed binary hex editing, automatic project-root working directory resolution, decoupled CUA-style clipboard mappings, and split-preserving buffer deletion.

## Requirements

### Vim Runtime

- **Vim 9.0+** (required): `vimrc`, `after/ftplugin/python.vim`, and all `plugin/*.vim` modules are implemented in `vim9script`.
    - `+clipboard` (recommended): required for system clipboard (`+`) shortcuts and `cs` path copying (`if has('clipboard')`).
    - `+python3` (required for Python formatting): needed by `pack/python/start/black` (requires Python 3.10+ support).
    - `+job` and `+channel` (recommended): used by `pack/util/opt/lsp`, `pack/util/opt/vim-grepper`, and non-shell external `xxd` execution in `plugin/binary.vim`.
- **Vim 9.1.0375+** (recommended): unlocks all built-in optional runtime packages and window protections:
    - `9.0.1799+`: built-in `editorconfig` package (`packadd! editorconfig`).
    - `9.1.0085+`: `'winfixbuf'` window protection support in `:Bdelete`.
    - `9.1.0375+`: built-in `comment` package (`packadd! comment`).

### Core CLI Utilities

Ensure the following executables are available in `PATH`:

- [Git](https://git-scm.com/) (`git`): submodule management, `.git` project-root detection, and fallback search backend.
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`): primary project search backend for `vim-grepper` and fast file indexer for `ctrlp.vim` (`rg --files %s`).

### Font

- [Inconsolata for Powerline](https://github.com/powerline/fonts/tree/master/Inconsolata): configured for GVim on Windows (`Inconsolata_for_Powerline:h14:cANSI`) and Linux GTK2/GTK3 (`Inconsolata for Powerline Medium 17`), paired with `g:airline_powerline_fonts = 1`.

### Optional External Tools

| Tool | Purpose | Activation Condition |
| --- | --- | --- |
| `clangd` | C/C++ language server (`pack/util/opt/lsp` via `plugin/lsp.vim`) | Lazy-loaded on `FileType c,cpp` only when `clangd` is found in `PATH` (zero startup overhead otherwise). |
| `xxd` | Binary inspection and reversible hex editing (`plugin/binary.vim`) | Invoked by `:HexToggle` or `:HexMode`, on `vim -b`, and automatically when opening `*.fd`, `*.fv`, `*.rom`, `*.bin`, `*.efi`, `*.exe`, `*.hex`. |
| `rustfmt` | Rust source formatter (`pack/rust-lang/start/rust.vim`) | Runs automatically when saving `*.rs` files (`g:rustfmt_autosave = 1`). |
| Python 3 + `black` virtualenv | Python code formatter (`pack/python/start/black`) | Runs `:Black` automatically on `BufWritePre *.py` using `%USERPROFILE%\vimfiles\black` on Windows (`$HOME/vimfiles/black`) or `~/.vim/black` on Linux and Cygwin; running `:Black` initializes the virtualenv if missing or formats the buffer. |

## Installation

### Windows

Install the core CLI tools and clone the repository recursively into `%USERPROFILE%\vimfiles` (PowerShell):

```powershell
winget install Git.Git
winget install BurntSushi.ripgrep.MSVC
git clone --recursive https://github.com/aphroteus/vimfiles.git "$env:USERPROFILE\vimfiles"
```

In `cmd.exe`, replace `"$env:USERPROFILE\vimfiles"` with `"%USERPROFILE%\vimfiles"`.

### Linux and Cygwin

Clone the repository recursively into `~/.vim`:

```bash
git clone --recursive https://github.com/aphroteus/vimfiles.git ~/.vim
```

### Existing Clones

To initialize or synchronize submodules in an existing clone:

```bash
git submodule update --init --recursive
```

### Startup Precedence & Platform Notes

- **Vim startup precedence**: Ensure no standalone `%USERPROFILE%\_vimrc` (or `%HOME%\_vimrc` / `%HOME%\.vimrc`) on Windows or `~/.vimrc` on Linux and Cygwin exists. If a standalone home vimrc file is present, Vim loads it first and skips `%USERPROFILE%\vimfiles\vimrc` / `~/.vim/vimrc`.
- **Windows (`win32`)**: `vimrc` deduplicates and appends `C:\cygwin64\bin` and `%HOME%\bin` (resolved to `%USERPROFILE%\bin` when `HOME` is unset) to `PATH` if present, maximizes GVim on startup, and stores swap files in `$TEMP//` (encoding full file paths via trailing `//`).
- **Linux (`unix`)**: `vimrc` stores swap files in `/tmp//` (encoding full file paths via trailing `//`) and configures initial GTK2/GTK3 GVim window dimensions (`50x170`).
- **Cygwin (`win32unix`)**: `vimrc` configures idempotent `DECSCUSR` terminal cursor-shape escape sequences (blinking block in Normal mode, blinking bar in Insert mode, default reset on exit) and enables mouse support (`set mouse=a`).

## Keybindings & Custom Commands

Note: `<Leader>` uses Vim's default `\` key.

### Search & Navigation

| Mode | Key / Command | Action |
| --- | --- | --- |
| Normal | `<F2>` | Search word under cursor across project (`:Grepper -cword -noprompt`) and open quickfix |
| Normal | `<F3>` | Open interactive `:Grepper` prompt (supports single keywords or quoted phrases) |
| Normal / Visual | `gs{motion}` / `gs` | Search text covered by `{motion}` or visual selection via `vim-grepper` |
| Command-line | `:Grepper [args...]` | Run asynchronous project search with tab completion (filters `rg`, `git`, `findstr`, `grep` by `PATH`) |
| Normal / Command-line | `<C-p>` / `:CtrlP` | Fuzzy file finder (`rg --files` backend when available; regex mode and persistent cache enabled) |
| Normal | `<A-n>` / `<A-p>` | Jump to next (`:cnext`) / previous (`:cprev`) quickfix entry |

### Buffer & Window Management

| Mode | Key / Command | Action |
| --- | --- | --- |
| Normal | `[b` / `]b` | Switch to previous (`:bprevious`) / next (`:bnext`) listed buffer (no-op in `quickfix` and `nofile` windows; quickfix buffers are unlisted) |
| Normal | `<Leader>bd` | Delete current buffer without closing split windows (`:Bdelete`) |
| Command-line | `:Bdelete[!] [buf]` | Delete target buffer (`%`, `#`, number, or name/substring) while preserving split layouts even under `'nohidden'`; guards modified buffers, running terminal jobs, and `'winfixbuf'` windows (`!` overrides) |

### Clipboard & Path Utilities

Active when `has('clipboard')` is enabled. The unnamed register (`""`) remains decoupled from the system clipboard (`+`) so Normal-mode `dd`, `x`, and `c` edits never clobber clipboard contents. Because `<C-v>` in Normal mode pastes from `+`, use Vim's built-in `<C-q>` to enter Visual Block mode.

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal | `<C-v>` | Paste from system clipboard (`+`) and place cursor at end of pasted text (`"+gP`) |
| Normal | `<C-q>` | Enter Visual Block mode (built-in alternative when `<C-v>` is mapped) |
| Normal | `cs` | Copy project-relative buffer path (`expand("%")`, anchored by `plugin/cwd.vim`) to system clipboard and echo it |
| Visual | `<C-c>` | Copy visual selection to system clipboard (`"+y`) |
| Visual | `<C-x>` | Cut visual selection to system clipboard (`"+x`) |
| Visual | `<C-v>` | Replace visual selection with system clipboard content (`"+p`) |
| Insert | `<C-v>` | Paste from system clipboard preserving indentation with an undo breakpoint (`<C-g>u<C-r><C-p>+`) |
| Command-line | `<C-v>` | Insert system clipboard text into command or search line (`<C-r>+`) |

### C / C++ LSP (`clangd`)

Buffer-local mappings registered on `User LspAttached` (`plugin/lsp.vim`) for `c` and `cpp` buffers when `clangd` is available in `PATH`:

| Mode | Shortcut | Action |
| --- | --- | --- |
| Normal (`c`, `cpp`) | `gd` | Go to definition (`:LspGotoDefinition`) |
| Normal (`c`, `cpp`) | `gi` | Go to implementation (`:LspGotoImpl`) |
| Normal (`c`, `cpp`) | `K` | Show hover documentation (`:LspHover`) |
| Normal (`c`, `cpp`) | `<Leader>ca` | Invoke code action (`:LspCodeAction`) |
| Normal (`c`, `cpp`) | `<Leader>f` | Format buffer via `clangd` (`:LspFormat`) |
| Normal (`c`, `cpp`) | `[d` / `]d` | Jump to previous (`:LspDiag prev`) / next (`:LspDiag next`) diagnostic |

### Binary & Hex Editing

Provided by `plugin/binary.vim` (commands: `:HexToggle` and `:HexMode [on|off|toggle|status]`):

| Command | Action |
| --- | --- |
| `:HexToggle` | Toggle current buffer between raw binary mode and `xxd` hex view |
| `:HexMode [mode]` | Set or query hex mode (`on`, `off`, `toggle`, `status`; tab-completed) |

- **Auto-triggered binary & firmware formats**: Opening `*.fd`, `*.fv`, `*.rom`, `*.bin`, `*.efi`, `*.exe`, `*.hex` (or invoking `vim -b`) enforces `binary`, `nofixendofline`, and `fileformat=unix`, converts the buffer to `xxd` hex view on read, and intercepts `:w`, `:w!`, range writes, and `:w >>` to validate hex syntax and write lossless raw bytes back to disk.
- **`g:binary_xxd_options` reversibility safeguard**: Optional string of `xxd` flags. Reversible formatting flags (`-c`/`-cols`, `-g`/`-groupsize`, `-p`/`-ps`/`-postscript`/`-plain`, `-u`) allow full round-trip binary editing and saving. Irreversible display flags (`-b`/`-bits`, `-i`/`-include`, `-e`, `-a`/`-autoskip`, `-E`/`-EBCDIC`, `-d`, `-C`/`-capitalize`, `-s`/`-seek`, `-l`/`-len`, `-o`, `-n`/`-name`) permit read-only hex inspection while blocking `:HexMode off` and binary writes to prevent data corruption.

### Editing & Configuration Utilities

| Mode | Key / Command | Action |
| --- | --- | --- |
| Normal / Visual | `gcc` / `gc{motion}` / `gc` | Toggle line or selection comments via built-in `comment` package (Vim `9.1.0375+`) |
| Insert | `<Leader>[` / `<Leader>]` | Insert dated `// (PaulHuang-YYYYMMDD-00) - start` or `end` marker and return to Normal mode |
| Normal (`*.log`) | `<F5>` | Reload log file from disk and jump to end of buffer (`pack/syntax/start/vim-uefi`, controlled by `g:uefi_log_f5_reload`) |
| Normal | `<Leader>ev` | Edit `$MYVIMRC` |
| Normal | `<Leader>sv` | Reload `$MYVIMRC` in place |

## Repository Structure & Plugins

### Configuration & Custom Modules

- `vimrc`: Core settings, OS/GUI configuration, built-in package loading, clipboard/buffer/quickfix mappings, and plugin options.
- `after/ftplugin/python.vim`: PEP 8 buffer-local Python settings (4-space indentation, `textwidth=79`, `expandtab`, `fileformat=unix`, with `b:undo_ftplugin` chaining).
- `plugin/bdelete.vim`: Split-preserving `:Bdelete` implementation compatible with `'nohidden'`, terminal job guards, and `'winfixbuf'`.
- `plugin/binary.vim`: Lossless `xxd`-backed binary inspection and hex editing (`:HexToggle`, `:HexMode`, `BufWriteCmd` raw write-back, `g:binary_xxd_options` validation).
- `plugin/cwd.vim`: Automatic window-local working directory (`lcd!`) resolution to the outermost enclosing project root (`.git`, `.repo`, `.hg`, `.svn`, `.bzr`, `_darcs`, `.vimprojects`) or buffer directory.
- `plugin/grepper.vim`: Lazy-loading command/operator stubs (`<F2>`, `<F3>`, `gs`, `:Grepper`), executable tool filtering, quickfix auto-open, and dynamic `vim-airline` integration for `pack/util/opt/vim-grepper`.
- `plugin/lsp.vim`: On-demand `packadd lsp` loader and buffer-local LSP keybindings on `FileType c,cpp` when `clangd` is executable.
- `.editorconfig` and `.gitattributes`: Formatting rules and cross-platform LF line-ending enforcement.

### Bundled Packages

| Package / Path | Loading | Source | Purpose |
| --- | --- | --- | --- |
| `editorconfig` | Conditional (`opt/`, `9.0.1799+`) | Built-in `$VIMRUNTIME` | EditorConfig integration (`packadd! editorconfig`) |
| `comment` | Conditional (`opt/`, `9.1.0375+`) | Built-in `$VIMRUNTIME` | Native `gc` / `gcc` comment toggling (`packadd! comment`) |
| `pack/syntax/start/vim-uefi` | Eager (`start/`) | [aphroteus/vim-uefi](https://github.com/aphroteus/vim-uefi) | UEFI/EDK II (`*.dec`, `*.dsc`, `*.fdf`, `*.inf`, `*.uni`, `*.vfr`, `*.sdl`), ACPI ASL (`*.asl`, `*.asi`, `*.dsl`), UEFI C syntax, and `*.log` `<F5>` reload |
| `pack/ui/start/vim-airline` | Eager (`start/`) | [vim-airline/vim-airline](https://github.com/vim-airline/vim-airline) | Statusline and buffer tabline |
| `pack/ui/start/vim-airline-themes` | Eager (`start/`) | [vim-airline/vim-airline-themes](https://github.com/vim-airline/vim-airline-themes) | Themes for `vim-airline` (`molokai`) |
| `pack/ui/start/vim-monokai` | Eager (`start/`) | [crusoexia/vim-monokai](https://github.com/crusoexia/vim-monokai) | `monokai` colorscheme |
| `pack/util/start/ctrlp.vim` | Eager (`start/`) | [ctrlpvim/ctrlp.vim](https://github.com/ctrlpvim/ctrlp.vim) | Fuzzy file, buffer, and MRU finder |
| `pack/rust-lang/start/rust.vim` | Eager (`start/`) | [rust-lang/rust.vim](https://github.com/rust-lang/rust.vim) | Rust filetype support and `rustfmt` on save |
| `pack/python/start/black` | Eager (`start/`) | [psf/black](https://github.com/psf/black) | Python `:Black` formatter on save |
| `pack/util/opt/vim-grepper` | Lazy (`opt/`) | [aphroteus/vim-grepper](https://github.com/aphroteus/vim-grepper) (`dev`) | Asynchronous project search (loaded on `<F2>`, `<F3>`, `gs`, or `:Grepper`) |
| `pack/util/opt/lsp` | Lazy (`opt/`) | [yegappan/lsp](https://github.com/yegappan/lsp) | Vim9 LSP client (loaded on `FileType c,cpp` when `clangd` is in `PATH`) |

## License

MIT License. See [LICENSE](LICENSE) for details.
