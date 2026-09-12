#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# dotfiles install — Nicholas Velten
# Usa GNU Stow para criar symlinks de cada módulo no $HOME.
#
# Uso:
#   ./install.sh              — instala todos os módulos
#   ./install.sh nvim         — instala só o nvim
#   ./install.sh nvim hypr    — instala múltiplos
#
# Módulos ativos: shell, editor, terminal, compositor, barra, launcher,
# notificações, tmux, Workmux, scripts e serviços de usuário.
# ══════════════════════════════════════════════════════════════════

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_MODULES=(bash git nvim hypr bin systemd ghostty tmux workmux atuin \
               waybar walker mako lazygit starship fastfetch)

# ── Verificar dependências ────────────────────────────────────────
check_deps() {
  local missing=()
  for dep in stow git; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Dependências faltando: ${missing[*]}"
    echo "   Instale com: sudo pacman -S ${missing[*]}"
    exit 1
  fi
}

# ── Instalar módulo via stow ──────────────────────────────────────
stow_module() {
  local module=$1
  echo "→ Instalando $module..."
  stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$module"
  echo "  ✓ $module"
}

# ── Main ──────────────────────────────────────────────────────────
check_deps

if [[ $# -eq 0 ]]; then
  echo "Instalando todos os módulos..."
  for module in "${STOW_MODULES[@]}"; do
    stow_module "$module"
  done
  if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload
  fi
else
  for arg in "$@"; do
    if [[ -d "$DOTFILES_DIR/$arg" ]]; then
      stow_module "$arg"
    else
      echo "⚠  Módulo '$arg' não encontrado — ignorando"
    fi
  done
fi

echo ""
echo "✓ Pronto!"
