# Personal Unix setup

My desktop and development environment, managed with GNU Stow.

The active stack is:

- Hyprland, Waybar, Walker and Mako
- Ghostty, Bash, tmux and Workmux
- Neovim and Emacs with Org mode
- Yazi, btop, git, glab, Elfeed and mpv
- systemd user services for theme, wallpaper and vault tasks

## Install

```bash
git clone https://github.com/nfvelten/dotfiles
cd dotfiles
./install.sh
```

Install a single module when needed:

```bash
./install.sh nvim
./install.sh hypr tmux workmux
```

The installer only includes active modules. Omarchy-specific modules and
themes were removed from the active tree.

## Reproduce the machine

Package and service state lives in `packages/`:

- `pacman.txt` — official repository packages
- `aur.txt` — AUR packages
- `user-services.txt` — enabled user units

```bash
make bootstrap
make check
```

Refresh the manifests after an intentional package or service change:

```bash
pacman -Qqe | sort > packages/pacman.txt
pacman -Qqm | sort > packages/aur.txt
comm -23 packages/pacman.txt packages/aur.txt > /tmp/pacman-native
mv /tmp/pacman-native packages/pacman.txt
systemctl --user list-unit-files --state=enabled --no-legend \
  | awk '{print $1}' | sort > packages/user-services.txt
```

## Layout

Each top-level directory is a Stow package. Files inside it mirror their
destination under `$HOME`.

```text
bash/       shell startup
bin/        small user commands
ghostty/    terminal
hypr/       compositor and desktop bindings
mako/       notifications
nvim/       editor
systemd/    user units and timers
tmux/       multiplexer
waybar/     status bar
walker/     launcher
workmux/    project workflow
```

Scripts in `bin/.local/bin` should do one small thing and depend only on
commands listed in the package manifests. `scripts/` contains repository
maintenance tools, such as `check-setup`.

## Theme

The shared palette is Yerba Mate for dark mode and Tererê for light mode.
Theme changes are handled by the desktop theme service and consumed by the
desktop, terminal, tmux, btop, Neovim and Emacs configurations.

## Checks

```bash
git diff --check
make check
shellcheck install.sh scripts/check-setup bin/.local/bin/*
```
