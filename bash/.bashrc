# shellcheck shell=bash
# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# ── Aliases ───────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'
alias cat='bat --paging=never'
alias catp='bat'
alias kc='kubectl'
alias k9s-contabo='k9s'
alias pub='bash ~/code/site/sync.sh'
alias pub-dry='bash ~/code/site/sync.sh --dry'
alias restart-portals='systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal'
alias teams='chromium --app=https://teams.microsoft.com'

# ── Funções ───────────────────────────────────────────────────────
miniflux() {
  docker compose -f ~/code/miniflux/compose.yml "$@"
}

# ── Local, fora do git ────────────────────────────────────────────
# secrets  — variáveis de ambiente sensíveis
# work.sh  — funções de trabalho (bancos, tokens); fora do repo público
[ -f ~/.config/amphora/secrets ] && source ~/.config/amphora/secrets
[ -f ~/.config/amphora/work.sh ] && source ~/.config/amphora/work.sh

# ── Shell tooling ─────────────────────────────────────────────────
[[ -f /usr/share/bash-preexec/bash-preexec.sh ]] && source /usr/share/bash-preexec/bash-preexec.sh
eval "$(atuin init bash)"
eval "$(direnv hook bash)"   # env por diretório via .envrc
