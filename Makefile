SHELL := /usr/bin/bash

.PHONY: bootstrap packages user-services theme theme-dark theme-light check

bootstrap: packages user-services check

packages:
	@sudo pacman -S --needed - < packages/pacman.txt
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
