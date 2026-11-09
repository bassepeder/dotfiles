# dotfiles

My macOS setup. yabai and skhd for tiling, JankyBorders, Neovim (LazyVim), kitty, zsh with starship, lazygit, delta and btop.

## Theme and font

Kitty, Neovim, delta, lazygit, bat and btop share one theme, Catppuccin or Modus. It follows the macOS appearance (Latte/Mocha, Operandi/Vivendi) unless I pin it to light or dark. Kitty and Neovide share a font as well.

In Neovim it's `:Theme` and `:Font`. From a shell:

```bash
theme set modus            # follows the system
theme set catppuccin dark
theme font c64             # jetbrains, fira, terminus or c64
theme                      # what's set right now
```

The state is in `theme/state`. `theme` writes what each tool reads (kitty's auto theme files and `font.conf`, `bat/config`, a delta include), all gitignored. Shells that were already open keep the old bat theme until they're restarted.

## cmode

A separate terminal for writing C, set up like an old console: bare prompt, plain BSD tools, strict C99 builds and a small Neovim config without plugins (`nvim-c/`). It doesn't touch the normal setup.

<table>
  <tr>
    <td><img src="screenshots/cmode-ghostty.png" alt="cmode in Ghostty: nvim-c with a C file and its -O2 assembly side by side"></td>
    <td><img src="screenshots/cmode-c64.png" alt="cmode --c64: the same file in the Commodore 64 font"></td>
  </tr>
  <tr>
    <td align="center"><code>cmode</code> with <code>:Asm</code></td>
    <td align="center"><code>cmode --c64</code></td>
  </tr>
</table>

<img src="screenshots/cmode-kitty.png" alt="cmode --kitty: building and running a brainfuck interpreter, with the exit code in the prompt after a failed command">

<details>
<summary>Usage and keys</summary>

```bash
cmode                # Ghostty, in the current directory
cmode ~/src/kilo     # somewhere else
cmode --kitty        # kitty instead of Ghostty
cmode --c64          # Commodore 64 font
cmode --no-crt       # Ghostty without the CRT effect
```

Ghostty is the default. It runs the screen through `ghostty-cmode/crt.glsl`, which is my cool-retro-term profile (`cool_retro_term.json`) redone as a shader. `--no-crt` turns the effect off, and `--kitty` is the same thing in kitty. Both use Modus Vivendi, the deuteranopia variant, on black.

Panes work as in my kitty: `Cmd-D` / `Cmd-Shift-D` split (in kitty `Cmd-Enter`), and `Cmd-h/j/k/l` move between them. A new pane is a cmode shell too, handy for running a server next to the editor.

The font starts out as whatever `theme font` is. `:Font` in nvim-c, or `cmode font <id>` in the shell, changes it for that window only.

The prompt is just the directory, with the exit code in front when something fails (`[134] ~/src/kilo $`). `CFLAGS` is `-std=c99 -Wall -Wextra -Wpedantic -g -O0 -fsanitize=address,undefined`, so `make foo` builds `foo.c` without a Makefile. In projects with a Makefile, run `bear -- make` once so clangd sees the real flags.

### nvim-c

The keys are the ones from my main config where there's an equivalent, LSP keys included. `,` is the leader, and `?` shows all of this inside Neovim.

| Key | |
|---|---|
| `,ff` `,fg` `,fb` | find files, grep, open buffers |
| `Space e` | file explorer (netrw as a sidebar, `q` closes it) |
| `Space Space` | list the problems, errors first (`Space i` all of them, `Space d` shows or hides the list) |
| `]d` `[d` | next/previous problem, with its message. `Ctrl-w d` shows it again |
| `gd` `ge` | definition (`Ctrl-o` goes back) |
| `gr` `gn` | references |
| `gD` `gE` | declaration |
| `gI` | implementation |
| `gy` | type definition |
| `K` `gh` | hover |
| `gK` | signature help (`Ctrl-k` while typing) |
| `]]` `[[` | next/previous use of the word under the cursor |
| `M` | man page for the word, system calls (2) and the C library (3) first |
| `,cr` | rename |
| `,ca` `,cA` | code action / source action |
| `,ss` `Space o` | symbols in the file (`,sS` / `Space O` in the project) |
| `Ctrl-x Ctrl-o` | completion, which never pops up by itself |

Problems, build errors and references end up in the quickfix list. There `Tab`/`Shift-Tab` step through the entries while the code follows, `Enter` jumps to one and closes the list, and `q` or `Esc` closes it. `,qf` brings it back. `Tab`/`Shift-Tab` also move through the results in the finders.

Building and running are commands rather than keys:

| Command | |
|---|---|
| `:make` | build, with the Makefile if there is one, else `make <file>`. It saves first and opens the list if there are problems |
| `:Run` | `make run` if the Makefile has that target, else `./<file>`, in a split. `q` closes it and stops the program |
| `:Debug` | lldb on `./<file>` in a split |
| `:Asm` | the file's `-O2` assembly next to it |
| `:Hex` | hex view (open binaries with `nvim -b`) |
| `:Font` | this window's font |

The g-keys are the same ones as in my main Neovim config. The finders are fzf in a floating terminal, so the colour theme is the only plugin.

`:w` formats C with clang-format (built into clangd), using the nearest `.clang-format`, so `~/.clang-format` unless the project has its own. While typing, indentation follows the file or its `.editorconfig`, and new files get 2 spaces. Anything past column 80 is highlighted. The statusline is an Emacs mode line, `-UU-:**-  F1  bf.c  62% L218  (C E1 W2)`: `**` is modified (`%%` read-only), then the tab number, file, position, line, and the filetype with clangd's error and warning counts.

</details>

## Install

```bash
git clone https://github.com/bassepeder/dotfiles.git ~/dotfiles
cd ~/dotfiles
brew bundle
./install.sh
```

`install.sh` symlinks the configs into place and checks that yabai and skhd still have their macOS permissions. It also downloads C64 Pro Mono, since that font can't be redistributed.

yabai isn't in the Brewfile. I run my own fork with fixes for macOS 27, see `yabai/README.md`.

## Local overrides

Anything machine specific (work vs. personal, secrets) lives in untracked files that the configs source if they exist:

- `~/.zshrc.local`
- `~/.gitconfig.local`
- `~/.yabairc.local`
