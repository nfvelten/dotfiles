SHELL := /usr/bin/bash

.PHONY: bootstrap packages sync-layers install-core install-desktop install-development install-optional install-aur user-services theme theme-dark theme-light check doctor snapshot restore org-status org-backup

bootstrap: packages user-services check

packages:
	@sudo pacman -S --needed - < packages/pacman.txt
	@yay -S --needed - < packages/aur.txt

sync-layers:
	@scripts/sync-layers

install-core:
	@sudo pacman -S --needed - < packages/layers/core.txt

install-desktop:
	@sudo pacman -S --needed - < packages/layers/desktop.txt

install-development:
	@sudo pacman -S --needed - < packages/layers/development.txt

install-optional:
	@sudo pacman -S --needed - < packages/layers/optional.txt

install-aur:
	@yay -S --needed - < packages/aur.txt

user-services:
	@systemctl --user daemon-reload
	@while read -r unit; do systemctl --user enable "$$unit"; done < packages/user-services.txt

theme:
	@desktop-theme-auto

theme-dark:
	@desktop-theme-auto dark

theme-light:
	@desktop-theme-auto light

check:
	@scripts/check-setup

doctor: check
	@hyprctl configerrors
	@git diff --check

snapshot:
	@pacman -Qqe | sort > packages/pacman.txt
	@pacman -Qqm | sort > packages/aur.txt
	@comm -23 packages/pacman.txt packages/aur.txt > /tmp/pacman-native
	@mv /tmp/pacman-native packages/pacman.txt
	@scripts/sync-layers
	@systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $$1}' | sort > packages/user-services.txt
	@echo "Manifests updated. Review with: git diff"

restore:
	@./install.sh
	@$(MAKE) packages user-services

org-status:
	@git -C "$(HOME)/org" status --short

org-backup:
	@if [ ! -d "$(HOME)/org/.git" ]; then git -C "$(HOME)/org" init; fi
	@git -C "$(HOME)/org" add -A
	@git -C "$(HOME)/org" diff --cached --quiet || git -C "$(HOME)/org" commit -m "chore: save org vault"
