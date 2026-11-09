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

`cmode [--c64] [dir]` opens a separate kitty window for writing C that feels like an old console. It uses Terminus on Modus Vivendi black and stays opaque, whatever the shared theme is. Inside it:

- **Shell:** a bare prompt (`[139] ~/src/kilo $` after a segfault), with no starship, no autosuggestions and plain BSD `ls`/`cat`/`man`.
- **Builds:** strict C99 by default: `CFLAGS='-std=c99 -Wall -Wextra -Wpedantic -g -O0 -fsanitize=address,undefined'`, so `make foo` builds `foo.c` without a Makefile.
- **Editor:** `nvim` is `nvim-c/`, a plugin-free config. It has clangd for definitions and errors, `:make` with the quickfix list, `K` for libc man pages, `<leader>a` for the file's assembly, `:Hex`, and lldb in a split. The key list is at the top of `nvim-c/init.lua`. For Makefile projects, run `bear -- make` once so clangd sees the real flags.

`--c64` uses C64 Pro Mono instead of Terminus.

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
