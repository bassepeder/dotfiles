#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

usage() {
  cat <<EOF
Usage: ./install.sh [--skip-perms]

  --skip-perms  skip the yabai/skhd permission check
EOF
}

SKIP_PERMS=0
for arg in "$@"; do
  case "$arg" in
  --skip-perms) SKIP_PERMS=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $arg" >&2
    usage >&2
    exit 1
    ;;
  esac
done

echo "Installing from $DOTFILES"
echo

if [ -f "$DOTFILES/Brewfile" ] && command -v brew >/dev/null 2>&1; then
  if ! HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --file="$DOTFILES/Brewfile" >/dev/null 2>&1; then
    echo "⚠️  Some dependencies are missing. To install them:"
    echo "      brew bundle --file=\"$DOTFILES/Brewfile\""
    echo "    Continuing with symlinks; anything missing will simply not start."
    echo
  fi
fi

link() {
  # `ln -sfn DIR TARGET` on a real directory would link inside it instead of replacing it
  if [ -d "$2" ] && [ ! -L "$2" ]; then
    echo "⚠️  skipping $2: real directory in the way"
    return
  fi
  ln -sfn "$1" "$2"
}

grep -qs 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile

mkdir -p ~/.config "$HOME/Library/Application Support/lazygit"

link "$DOTFILES/nvim" ~/.config/nvim
link "$DOTFILES/yabai/.yabairc" ~/.yabairc
# gives the scripts .yabairc calls a stable path
link "$DOTFILES/yabai" ~/.config/yabai
link "$DOTFILES/skhd/.skhdrc" ~/.skhdrc
link "$DOTFILES/borders" ~/.config/borders
link "$DOTFILES/.clang-format" ~/.clang-format
link "$DOTFILES/.zshrc" ~/.zshrc
link "$DOTFILES/git/.gitconfig" ~/.gitconfig
link "$DOTFILES/starship.toml" ~/.config/starship.toml
link "$DOTFILES/kitty" ~/.config/kitty
link "$DOTFILES/btop" ~/.config/btop
link "$DOTFILES/bat" ~/.config/bat
link "$DOTFILES/theme" ~/.config/theme
mkdir -p ~/.local/bin
link "$DOTFILES/theme/theme" ~/.local/bin/theme
# cmode: a stripped-down console for C (scripts/cmode)
link "$DOTFILES/kitty-cmode" ~/.config/kitty-cmode
link "$DOTFILES/nvim-c" ~/.config/nvim-c
link "$DOTFILES/scripts/cmode" ~/.local/bin/cmode
link "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# C64 Pro Mono (for `theme font c64`) may not be redistributed, so it isn't in
# this repo or Homebrew; fetch it from the publisher when it's missing
if ! ls ~/Library/Fonts/C64_Pro_Mono-STYLE.ttf >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/c64.zip" https://style64.org/file/C64_TrueType_v1.2.1-STYLE.zip &&
    unzip -q -j "$tmp/c64.zip" 'C64_TrueType_v1.2.1-STYLE/fonts/C64_Pro_Mono-STYLE.ttf' -d "$tmp"; then
    mkdir -p ~/Library/Fonts
    cp "$tmp/C64_Pro_Mono-STYLE.ttf" ~/Library/Fonts/
    echo "Installed C64 Pro Mono"
  else
    echo "⚠️  could not download C64 Pro Mono from style64.org"
  fi
  rm -rf "$tmp"
fi

# writes the generated kitty/bat/delta theme and font files (gitignored)
"$DOTFILES/theme/theme" apply

echo
if command -v yabai >/dev/null 2>&1; then
  if yabai --restart-service >/dev/null 2>&1; then
    echo "yabai restarted (picks up .yabairc, which launches borders)"
  else
    echo "⚠️  could not restart yabai — try: yabai --restart-service"
  fi
else
  # interactive (sudo, permission prompts), so not run from here
  echo "⚠️  yabai is not installed. It comes from a fork with macOS 27 fixes:"
  echo "      curl -fsSL https://raw.githubusercontent.com/bassepeder/yabai/macos27/scripts/install-fork.sh | bash"
fi

# TCC grants are keyed to the resolved Cellar path, so `brew upgrade` silently revokes them

tcc_granted() { # $1=service  $2=resolved binary path
  local v
  v="$(sqlite3 "$TCC_DB" \
    "SELECT auth_value FROM access WHERE service='$1' AND client='$2' LIMIT 1;" \
    2>/dev/null || true)"
  [ "$v" = "2" ]
}

report() { # $1=label  $2=service  $3=binary
  local bin
  bin="$(command -v "$3" 2>/dev/null || true)"
  if [ -z "$bin" ]; then
    printf "  %-34s %s\n" "$1" "not installed — skipping"
    return 0
  fi
  bin="$(readlink -f "$bin")"
  if tcc_granted "$2" "$bin"; then
    printf "  %-34s granted\n" "$1"
  else
    printf "  %-34s MISSING\n" "$1"
    return 1
  fi
}

if [ "$SKIP_PERMS" -eq 0 ]; then
  echo
  echo "Checking yabai / skhd permissions"
  echo

  missing=0
  if [ -r "$TCC_DB" ]; then
    report "yabai  · Accessibility" kTCCServiceAccessibility yabai || missing=1
    report "skhd   · Accessibility" kTCCServiceAccessibility skhd || missing=1
    report "skhd   · Input Monitoring" kTCCServiceListenEvent skhd || missing=1
  else
    echo "  (cannot read $TCC_DB — check the panes manually)"
    missing=1
  fi

  # the sudoers rule is pinned to the binary's sha256, so it also breaks on upgrade
  if command -v yabai >/dev/null 2>&1 && [ -r /etc/sudoers.d/yabai ]; then
    want="$(shasum -a 256 "$(readlink -f "$(command -v yabai)")" | awk '{print $1}')"
    if grep -q "$want" /etc/sudoers.d/yabai; then
      printf "  %-34s current\n" "yabai  · scripting addition"
    else
      printf "  %-34s STALE (binary changed)\n" "yabai  · scripting addition"
      echo "      fix: sudo yabai --install-service && echo \\"
      echo "           \"\$(whoami) ALL=(root) NOPASSWD: sha256:$want \$(command -v yabai) --load-sa\" \\"
      echo "           | sudo tee /etc/sudoers.d/yabai"
    fi
  fi

  if [ "$missing" -eq 1 ]; then
    cat <<'EOF'

Some grants are missing. macOS will not let a script add them, so:

  1. In the pane that opens, click +
  2. Press Cmd+Shift+G and paste the FULL path printed below
     (the /opt/homebrew/bin symlink will not work — TCC needs the real path)
  3. Make sure the toggle next to it is on
EOF
    for b in yabai skhd; do
      p="$(command -v "$b" 2>/dev/null || true)"
      [ -n "$p" ] && echo "     $b -> $(readlink -f "$p")"
    done
    echo
    read -r -p "Open Privacy & Security now? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      read -r -p "Press Enter when done with Accessibility to open Input Monitoring... " _
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
      read -r -p "Press Enter when done... " _
    fi

    echo
    read -r -p "Restart yabai and skhd now? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      command -v yabai >/dev/null 2>&1 && yabai --restart-service || true
      launchctl kickstart -k "gui/$(id -u)/com.koekeishiya.skhd" 2>/dev/null || true
      echo "Restarted. If skhd still fails, check /tmp/skhd_$(whoami).err.log"
    fi
  fi
fi

echo
echo "✅ Dotfiles installed from $DOTFILES"
