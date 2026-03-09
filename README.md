# dotfiles

Configurações pessoais — Nicholas Velten.

Gerenciado com [GNU Stow](https://www.gnu.org/software/stow/).
Temas baseados na paleta **Cimarrão** (dark) e **Tererê** (light).

## Módulos

| Módulo | Destino | O que é |
|--------|---------|---------|
| `nvim` | `~/.config/nvim/` | Config completa do Neovim (LazyVim + plugins + temas) |
| `omarchy-themes` | `~/.config/omarchy/themes/` | Temas Yerba Mate (dark) e Tererê (light) para o Omarchy |
| `omarchy-hooks` | `~/.config/omarchy/hooks/` | Hook que sincroniza tema do Claude Code com o Omarchy |
| `hypr` | `~/.config/hypr/` | Keybindings Hyprland — Super+N (daily note), Super+C (Claude Code) e windowrules |
| `bin` | `~/.local/bin/` | Scripts: `daily-note` (scratchpad nvim), `claude-amphora` (scratchpad Claude Code) e `omarchy-theme-auto` |
| `systemd` | `~/.config/systemd/user/` | Timer que troca o tema automaticamente às 6h e 18h |
| `obsidian` | vault `/.obsidian/themes/Omarchy/` | Tema Obsidian com dark/light separados |

## Instalação rápida

```bash
git clone https://github.com/nfvelten/dotfiles
cd dotfiles
./install.sh
```

O script instala todos os módulos de uma vez via `stow`.

## Instalação por módulo

```bash
# Só o Neovim
./install.sh nvim

# Só os temas do Omarchy
./install.sh omarchy-themes

# Múltiplos
./install.sh nvim omarchy-themes omarchy-hooks
```

## Obsidian

O tema do Obsidian não usa symlink (o vault pode estar em qualquer lugar).
Defina a variável de ambiente com o caminho do seu vault:

```bash
OBSIDIAN_VAULT=~/meu-vault ./install.sh obsidian
```

Se não definir, o script procura em `~/obsidian` por padrão.

## Dependências

- `stow` — `sudo pacman -S stow` (Arch) / `sudo apt install stow` (Debian)
- `jq` — necessário para o hook do Claude Code (`omarchy-hooks`)

## Temas

### Yerba Mate — dark
Fundo oliva-industrial `#1c1e13`, texto prata `#dce0d9`, acento ocre `#a67c52`.

### Tererê — light
Fundo creme-manteiga `#fbf1c7`, texto carvão `#3c3836`, acento âmbar `#b57614`.

Troca automática baseada no horário: **6h–18h → Tererê**, **18h–6h → Yerba Mate** (via systemd timer).

Aplicados em: Neovim · Omarchy · Waybar · Terminal · Site pessoal · Obsidian
