# dotfiles

My macOS setup. yabai and skhd for tiling, JankyBorders, Neovim (LazyVim), kitty, zsh with starship, lazygit, delta and btop.

Kitty, Neovim, delta, lazygit, bat and btop share one theme: Catppuccin (Latte/Mocha) or Modus (Operandi/Vivendi). It either follows the macOS appearance or stays light or dark. Kitty and Neovide also share one font: JetBrains Mono, Fira Code, Terminus or Commodore 64 (C64 Pro Mono).

Switch them from Neovim with `:Theme` and `:Font`, which open pickers, or from a shell:

```bash
theme set modus          # follow the system
theme set catppuccin dark
theme font c64
theme                    # show the current setting
```

`theme/theme` keeps the state in `theme/state` and writes the per-tool files (`kitty/*.auto.conf`, `kitty/font.conf`, `bat/config`, `theme/delta.gitconfig`). All of them are gitignored and `install.sh` generates them. Running shells keep the old bat theme until they restart, because bat reads `~/.config/bat/config` and env vars override it.

## cmode

`cmode` opens a separate terminal window for writing C that feels like an old console. It has a bare prompt, plain tools, strict C99 builds and a small Neovim with no plugins. Nothing in it changes your normal setup.

<details>
<summary><b>Usage, options and the nvim-c keybindings</b></summary>

### Usage

```bash
cmode                 # Ghostty, in the current directory
cmode --kitty ~/src   # kitty, starting in ~/src
cmode --c64           # the Commodore 64 font
```

| Option | What it does |
|---|---|
| `--ghostty` | Ghostty with a CRT pass (`ghostty-cmode/crt.glsl`) that recreates the cool-retro-term profile in `cool_retro_term.json`: colours at half strength, a dark frame with rounded corners. This is the default. |
| `--kitty` | kitty, plain and sharp, with no CRT effect. |
| `--c64` | The Commodore 64 font (C64 Pro Mono) instead of your usual one. |
| `dir` | Where the window starts. Defaults to the current directory. |
| `-h`, `--help` | Show the usage. |

Both terminals use Modus Vivendi (the deuteranopia variant, which uses yellow and blue instead of red and green) on black, whatever the shared theme is.

### Fonts

A cmode window starts in your usual font (`theme font`), or C64 with `--c64`. Every window has its own font file, so changing the font affects only that window:

- `:Font` in nvim-c opens a picker, and `:Font c64` switches directly.
- `cmode font <id>` does the same from the window's shell. `cmode font` alone shows the current font.

The ids are the ones in `theme fonts`: `jetbrains`, `fira`, `terminus` and `c64`.

### Inside the window

- **Prompt:** just `~/src/kilo $`. A failing command's exit code appears in front, e.g. `[134] ~/src/kilo $` when AddressSanitizer aborts.
- **Shell:** no starship, no autosuggestions, and plain BSD `ls`, `cat` and `man`.
- **Builds:** `CFLAGS='-std=c99 -Wall -Wextra -Wpedantic -g -O0 -fsanitize=address,undefined'`, so `make foo` builds `foo.c` without a Makefile.
- **Editor:** `nvim` runs `nvim-c/`. clangd uses C99 flags unless the project has a `compile_commands.json`. For a Makefile project, run `bear -- make` once to create it.

### nvim-c keybindings

The leader key is <kbd>Space</kbd>.

| Key / command | What it does |
|---|---|
| <kbd>Space</kbd> <kbd>m</kbd> | Build. Runs `make` if there's a Makefile, else `make <file>`. Errors and warnings open the quickfix list. |
| <kbd>Space</kbd> <kbd>r</kbd> / `:Run [cmd]` | Run `./<file>` (or `cmd`) in a terminal split. |
| <kbd>Space</kbd> <kbd>d</kbd> / `:Debug [prog]` | Debug `./<file>` (or `prog`) with lldb in a terminal split. |
| <kbd>Space</kbd> <kbd>a</kbd> / `:Asm` | Show the file's `-O2` assembly in a split. |
| `:Hex` | Toggle a hex view of the buffer. Open binaries with `nvim -b`. |
| `:Font [id]` | Switch this window's font. Without an id it opens a picker. |
| <kbd>K</kbd> | Man page for the word under the cursor, libc (section 3) first. |
| <kbd>g</kbd> <kbd>K</kbd> | clangd hover. |
| <kbd>Ctrl</kbd>+<kbd>]</kbd> | Go to the definition. |
| <kbd>g</kbd> <kbd>r</kbd> <kbd>r</kbd> / <kbd>g</kbd> <kbd>r</kbd> <kbd>n</kbd> | References / rename (Neovim defaults). |
| <kbd>]</kbd> <kbd>d</kbd> / <kbd>[</kbd> <kbd>d</kbd> | Next / previous diagnostic. <kbd>Ctrl</kbd>+<kbd>w</kbd> <kbd>d</kbd> shows the message. |
| <kbd>Ctrl</kbd>+<kbd>x</kbd> <kbd>Ctrl</kbd>+<kbd>o</kbd> | Completion, only when you ask for it. |
| <kbd>Space</kbd> <kbd>f</kbd> | `:find`, which searches the whole tree. |
| <kbd>Space</kbd> <kbd>b</kbd> | List the buffers and pick one. |
| <kbd>-</kbd> | File browser (netrw). |
| <kbd>Esc</kbd> <kbd>Esc</kbd> | Leave terminal mode in a terminal split. |

Indentation follows each file (tabs stay tabs, 2/4/8 spaces stay as they are), an `.editorconfig` wins, and new files get 2 spaces. Tabs show as `»` and trailing spaces as `·`.

</details>

## Install

```bash
git clone https://github.com/bassepeder/dotfiles.git ~/dotfiles
cd ~/dotfiles
brew bundle
./install.sh
```

`install.sh` symlinks the configs into place and checks that yabai and skhd still have their macOS permissions.

yabai isn't in the Brewfile. I run my own fork with fixes for macOS 27, see `yabai/README.md`.

## Local overrides

Anything machine specific (work vs. personal, secrets) lives in untracked files that the configs source if they exist:

- `~/.zshrc.local`
- `~/.gitconfig.local`
- `~/.yabairc.local`
