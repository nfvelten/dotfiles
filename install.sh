#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# dotfiles install — Nicholas Velten
# Usa GNU Stow para criar symlinks de cada módulo no $HOME
#
# Uso:
#   ./install.sh              — instala todos os módulos
#   ./install.sh nvim         — instala só o nvim
#   ./install.sh nvim hypr    — instala múltiplos
#
# Módulos disponíveis:
#   nvim            → ~/.config/nvim/
#   omarchy-hooks   → ~/.config/omarchy/hooks/
#   hypr            → ~/.config/hypr/ (bindings + windowrules)
#   bin             → ~/.local/bin/ (daily-note, omarchy-theme-auto)
#   systemd         → ~/.config/systemd/user/ (timer troca automática de tema)
#   obsidian        → instala tema no vault (requer OBSIDIAN_VAULT)
#
# Temas Omarchy são instalados diretamente dos repos públicos:
#   github.com/nfvelten/omarchy-yerba-mate  → dark
#   github.com/nfvelten/omarchy-terere      → light
# ══════════════════════════════════════════════════════════════════

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_MODULES=(nvim omarchy-hooks hypr bin systemd)
OBSIDIAN_MODULE="obsidian"

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

# ── Instalar temas Omarchy dos repos públicos ────────────────────
install_omarchy_themes() {
  local themes_dir="$HOME/.config/omarchy/themes"
  mkdir -p "$themes_dir"

  for theme in yerba-mate terere; do
    local repo="omarchy-${theme}"
    local dest="$themes_dir/$theme"
    if [[ -d "$dest/.git" ]]; then
      echo "→ Atualizando $theme..."
      git -C "$dest" pull --ff-only
    else
      echo "→ Instalando $theme..."
      rm -rf "$dest"
      git clone "https://github.com/nfvelten/$repo.git" "$dest"
    fi
    echo "  ✓ $theme"
  done
}

# ── Instalar tema do Obsidian ─────────────────────────────────────
install_obsidian() {
  local vault="${OBSIDIAN_VAULT:-$HOME/obsidian}"

  if [[ ! -d "$vault" ]]; then
    echo "⚠  Vault Obsidian não encontrado em $vault"
    echo "   Defina OBSIDIAN_VAULT=/caminho/para/vault e rode novamente"
    return
  fi

  local dest="$vault/.obsidian/themes/Omarchy"
  mkdir -p "$dest"
  cp "$DOTFILES_DIR/$OBSIDIAN_MODULE/themes/Omarchy/theme.css" "$dest/theme.css"
  cp "$DOTFILES_DIR/$OBSIDIAN_MODULE/themes/Omarchy/manifest.json" "$dest/manifest.json"
  echo "  ✓ obsidian (vault: $vault)"
}

# ── Main ──────────────────────────────────────────────────────────
check_deps

if [[ $# -eq 0 ]]; then
  echo "Instalando todos os módulos..."
  for module in "${STOW_MODULES[@]}"; do
    stow_module "$module"
  done
  install_obsidian
  install_omarchy_themes
  # Ativa o timer de troca automática de tema
  if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload
    systemctl --user enable --now omarchy-theme-auto.timer 2>/dev/null && \
      echo "  ✓ timer omarchy-theme-auto ativado"
  fi
else
  for arg in "$@"; do
    if [[ "$arg" == "obsidian" ]]; then
      install_obsidian
    elif [[ -d "$DOTFILES_DIR/$arg" ]]; then
      stow_module "$arg"
    else
      echo "⚠  Módulo '$arg' não encontrado — ignorando"
    fi
  done
fi

echo ""
echo "✓ Pronto!"
