# shellcheck shell=bash
# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# ── Aliases ───────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'
alias cat='bat --paging=never'
alias catp='bat'
alias restart-portals='systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal'
alias wm='workmux'

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
eval "$(starship init bash)"
eval "$(atuin init bash)"
eval "$(direnv hook bash)"   # env por diretório via .envrc

if [[ -n ${TMUX:-} ]]; then
    export ATUIN_TMUX_POPUP=true
fi
