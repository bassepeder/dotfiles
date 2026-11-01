export EDITOR=nvim
export BROWSER=firefox

# frees ^Q for autosuggest-clear below
stty -ixon 2>/dev/null

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

mkdir -p ~/.local/state/zsh
HISTFILE=~/.local/state/zsh/history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_VERIFY
setopt SHARE_HISTORY

setopt AUTO_CD

autoload -Uz compinit
compinit

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion::complete:*' gain-privileges 1

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] &&
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ] && source /opt/homebrew/opt/fzf/shell/completion.zsh
[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh

export FZF_COMPLETION_TRIGGER='..'
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export FZF_DEFAULT_OPTS='--no-mouse --info=inline-right'

if command -v fd >/dev/null; then
  _fzf_compgen_path() { fd --hidden --follow --exclude ".git" . "$1" }
  _fzf_compgen_dir()  { fd --type d --hidden --follow --exclude ".git" . "$1" }
fi

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

if command -v eza >/dev/null; then
  alias ls='eza'
  alias ll='eza -l'
  alias la='eza -la'
  alias lt='eza --tree'
fi
if command -v bat >/dev/null; then
  alias cat='bat'
  export BAT_THEME_LIGHT="Catppuccin Latte"
  export BAT_THEME_DARK="Catppuccin Mocha"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

unalias neovide 2>/dev/null

alias lg="lazygit"
alias v="nvim"

command -v fnm >/dev/null && eval "$(fnm env --use-on-cd)"
export STARSHIP_CACHE="$HOME/.cache/starship"
eval "$(starship init zsh)"

bindkey -v

autoload -Uz edit-command-line
zle -N edit-command-line

bindkey "^H" autosuggest-execute
bindkey "^ " autosuggest-accept
bindkey "^Q" autosuggest-clear
bindkey -M vicmd "e" history-search-backward
bindkey -M vicmd "n" history-search-forward
bindkey -M vicmd "^[[A" history-search-backward
bindkey -M vicmd "^[[B" history-search-forward
bindkey -M vicmd "v" edit-command-line
bindkey -M viins "^L" clear-screen
bindkey -M viins "^W" backward-kill-word

bindkey "^[[A" fzf-history-widget

# must be sourced after all widgets/bindings
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] &&
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

psg() { ps aux | grep "$@" }
take() { mkdir -p "$1" && cd "$1" }
generate-password() { strings /dev/urandom | grep -o '[[:alnum:]]' | head -n "$1" | tr -d '\n'; echo }
where-from() { realpath "$(which "$1")" }
url-sha256() { curl -sL "$1" | shasum -a 256 | cut -d ' ' -f 1 | xxd -r -p | base64 }
c() { printf "%s\n" "$@" | bc -l }
dl() { $HOME/dotfiles/yabai/scripts/dev-layout.sh }
# btop can't follow the macOS appearance itself, so pick the theme at launch
btop() { command btop --themes-dir ~/.config/btop/themes/$(defaults read -g AppleInterfaceStyle &>/dev/null && echo mocha || echo latte) "$@" }

export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
# sbt would otherwise run on Homebrew's latest openjdk; Metals supports 17 and 21
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

# Homebrew's dotnet lives in libexec; global tool apphosts (e.g. easy-dotnet's server) need DOTNET_ROOT to find it
export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
export PATH="$PATH:$HOME/.dotnet/tools"
