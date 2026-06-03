############################
# PATH
############################
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"

############################
# Базовые настройки
############################
setopt AUTO_CD AUTO_PUSHD PUSHD_SILENT
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY
setopt EXTENDED_GLOB
unsetopt BEEP

# История
export HISTSIZE=200000
export SAVEHIST=200000
export HISTFILE="$HOME/.zsh_history"

############################
# Цвета, ls, grep
############################
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

alias ls="eza --group-directories-first --icons --git"
alias ll="ls -lah"
alias cat="bat --paging=never"
alias grep="rg"

############################
# Инструменты
############################
# fzf
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
# fzf keybindings + completion (Ctrl-R history, Ctrl-T files, Alt-C dirs)
source <(fzf --zsh)

# zoxide
eval "$(zoxide init zsh)"

# direnv
eval "$(direnv hook zsh)"

############################
# Antidote + плагины
############################
source "$(brew --prefix antidote)/share/antidote/antidote.zsh"

export ZSH_PLUGINS_FILE="$HOME/.zsh_plugins.txt"
if [[ ! -f "$ZSH_PLUGINS_FILE" ]]; then
  cat > "$ZSH_PLUGINS_FILE" <<'PLUGINS'
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-completions
junegunn/fzf
PLUGINS
fi

antidote load < "$ZSH_PLUGINS_FILE"

############################
# Prompt (starship)
############################
eval "$(starship init zsh)"

############################
# Алиасы
############################
alias please='sudo $(fc -ln -1)'

# Git
alias g='git'
alias gst='git status -sb'
alias ga='git add -A'
alias gc='git commit -v'
alias gca='git commit -a -v'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --max-count=30'
alias gco='git checkout'
alias gb='git switch -c'
alias gr='git rebase -i'

# Node / npm / pnpm
alias ni='npm i'
alias nr='npm run'
alias pni='pnpm i'
alias pr='pnpm run'

############################
# Функции
############################
mkcd() { mkdir -p "$1" && cd "$1"; }
grt() { cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"; }
extract() {
  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz)  tar xzf "$1" ;;
    *.zip)     unzip "$1" ;;
    *.tar)     tar xf "$1" ;;
    *)         echo "unsupported archive" ;;
  esac
}

############################
# Комплишн и ускорение
############################
bindkey -e

autoload -Uz compinit
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump"
mkdir -p "$(dirname "$ZSH_COMPDUMP")"
compinit -C -d "$ZSH_COMPDUMP"
export JAVA_HOME=$(/usr/libexec/java_home -v 21)

export EDITOR="zed --wait"
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
___MY_VMOPTIONS_SHELL_FILE="${HOME}/.jetbrains.vmoptions.sh"; if [ -f "${___MY_VMOPTIONS_SHELL_FILE}" ]; then . "${___MY_VMOPTIONS_SHELL_FILE}"; fi
