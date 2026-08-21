# dotfiles

Configurações pessoais — Nicholas Velten.

Gerenciado com [GNU Stow](https://www.gnu.org/software/stow/).
Temas baseados na paleta **Cimarrão** (dark) e **Tererê** (light).

## Módulos

| Módulo | Destino | O que é |
|--------|---------|---------|
| `alacritty` · `ghostty` · `tmux` | `~/.config/<app>/` | Configs de terminal e multiplexador |
| `starship` · `lazygit` · `fastfetch` | `~/.config/` | Prompt, TUI do git e fetch |
| `systemd` | `~/.config/systemd/user/` | Timers e serviços: tema automático, sync do vault, backup do homelab, deck |
| `bash` | `~/.bashrc` | Aliases, funções e init do shell (atuin, direnv, bash-preexec). Nada de trabalho — sourceia `~/.config/amphora/work.sh` se existir |
| `git` | `~/.config/git/` | Config global (delta como pager, rerere, rebase no pull) + hook `post-commit` |
| `nvim` | `~/.config/nvim/` | Config completa do Neovim (LazyVim + plugins + temas) |
| `omarchy-themes` | `~/.config/omarchy/themes/` | Temas Yerba Mate (dark) e Tererê (light) para o Omarchy |
| `omarchy-hooks` | `~/.config/omarchy/hooks/theme-set.d/` | Hook que sincroniza o tema do Claude Code, Zen e LibreWolf com o Omarchy |
| `omarchy-shell` | `~/.config/omarchy/` | Layout do shell, barra flutuante e plugins locais do Omarchy |
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

Ficam de fora por não terem destino nesta máquina (Omarchy 4 substituiu):
`mako`, `newsboat`, `walker`, `waybar`. Os arquivos seguem no repo.

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

## Stack de dev

Ferramentas de linha de comando da máquina. Repo oficial do Arch, exceto onde marcado.

```bash
sudo pacman -S --needed \
  ripgrep fd go-yq jq gron jless ripgrep-all pandoc-cli tokei \
  ast-grep git-delta difftastic lazygit github-cli glab \
  shellcheck shfmt just direnv watchexec \
  podman podman-compose k9s kubectl \
  oha hyperfine lnav mtr \
  bat eza fzf zoxide yazi glow atuin starship btop tldr
```

AUR:

```bash
yay -S usql   # REPL universal de banco
```

Fora do gerenciador de pacote (via `mise`/npm):

```bash
npm i -g @usebruno/cli        # bru — roda a air-api-collection
playwright install chromium   # ~650MB em ~/.cache/ms-playwright
```

### Por função

| Função | Ferramenta |
|--------|-----------|
| Busca | `rg` texto · `fd` arquivo · `ast-grep` por AST (callers, refactor) · `rga` dentro de PDF/docx/xlsx |
| Dados | `jq` JSON · `yq` YAML · `gron` achata pra grep · `jless` JSON grande · `pandoc` converte doc |
| Git | `delta` pager · `difft` diff estrutural · `lazygit` TUI · `gh` GitHub · `glab` GitLab |
| Shell | `shellcheck` lint · `shfmt` format |
| Infra | `podman` rootless · `podman-compose` · `just` tasks · `direnv` env por dir · `watchexec` roda ao mudar |
| Teste | `oha` carga HTTP · `hyperfine` benchmark · `bru` requests · `playwright` browser |
| DB | `usql` REPL universal (postgres/mysql/oracle) |
| Debug | `lnav` navegador de log · `mtr` rede · `k9s`/`kubectl` cluster |

### Config manual necessária

- **`delta`** — já configurado no módulo `git` (`core.pager`, `interactive.diffFilter`).
  Vem junto com `./install.sh git`.
- **`direnv`** — hook já incluído no módulo `bash`. Vem com `./install.sh bash`.

`podman` rootless precisa de `subuid`/`subgid` (o Arch já cria no install do pacote):

```bash
grep "^$USER" /etc/subuid /etc/subgid   # esperado: <user>:100000:65536
```

## Temas

### Yerba Mate — dark
Fundo oliva-industrial `#1c1e13`, texto prata `#dce0d9`, acento ocre `#a67c52`.

### Tererê — light
Fundo creme-manteiga `#fbf1c7`, texto carvão `#3c3836`, acento âmbar `#b57614`.

Troca automática baseada no horário: **6h–18h → Tererê**, **18h–6h → Yerba Mate** (via systemd timer).

Aplicados em: Neovim · Omarchy · Waybar · Terminal · Site pessoal · Obsidian
