# Tom OS Zsh setup
# Use a compact neon prompt and show the Tom OS Fastfetch artwork on interactive shells.
autoload -Uz compinit
if [[ -o interactive ]]; then
  compinit -C
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  fi
fi

setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# Violet user/host, cyan current directory.
PROMPT='%F{magenta}%n@%m%f:%F{cyan}%~%f %# '

# Handy aliases.
alias ll='ls -alF'
alias la='ls -A'
alias cls='clear'
alias update='sudo apt update && sudo apt upgrade'
