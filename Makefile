SHELL := /usr/bin/bash

.PHONY: bootstrap packages user-services check

bootstrap: packages user-services check

packages:
	@sudo pacman -S --needed - < packages/pacman.txt
	@yay -S --needed - < packages/aur.txt

user-services:
	@systemctl --user daemon-reload
	@while read -r unit; do systemctl --user enable "$$unit"; done < packages/user-services.txt

check:
	@scripts/check-setup
