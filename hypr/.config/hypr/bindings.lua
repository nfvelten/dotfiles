-- Portado do bindings.conf antigo (pre-quattro), perdido na migração pro Lua.

local osdclient = "swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\""
local browser = "omarchy-launch-browser"

o.bind("SUPER + grave", "Scratchpad terminal", "uwsm app -- $HOME/.local/bin/scratchterm")
o.bind("SUPER + CTRL + grave", "Window switcher", "uwsm app -- walker -m windows")
o.bind("SUPER + N", "Nvim", "uwsm app -- $HOME/.local/bin/scratchnvim")
o.bind("SUPER + H", "Keybindings", "uwsm app -- $HOME/.local/bin/scratchkeys")
o.bind("SUPER + C", "Herdr", "uwsm app -- $HOME/.local/bin/scratchherdr")
o.bind("SUPER + R", "Meeting Record", "uwsm app -- $HOME/.local/bin/meeting-record")

-- SUPER+RETURN, SUPER+ALT+RETURN e SUPER+SHIFT+RETURN já são o padrão do
-- Omarchy (Terminal/Tmux/Browser via {omarchy = "..."} em applications.lua),
-- não rebind aqui pra não abrir duplicado.
o.bind("SUPER + SHIFT + F", "File manager", "uwsm app -- ghostty -e yazi")
o.bind("SUPER + B", "LibreWolf", "omarchy-launch-or-focus librewolf \"uwsm app -- librewolf\"")
o.bind("SUPER + SHIFT + B", "Browser", browser)
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", browser .. " --private")
o.bind("SUPER + M", "Music player", "uwsm app -- $HOME/.local/bin/scratchspotify")
o.bind("SUPER + E", "Work nvim", "uwsm app -- $HOME/.local/bin/scratchwork")
hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Music", "omarchy shell -q quickshell.spotify.player togglePlayer")
o.bind("SUPER + SHIFT + ALT + M", "Music TUI", "omarchy-launch-or-focus-tui cliamp")
o.bind("SUPER + SHIFT + N", "Editor", "omarchy-launch-editor")
o.bind("SUPER + SHIFT + T", "Activity", "omarchy-launch-tui btop")
o.bind("SUPER + SHIFT + D", "Docker", "omarchy-launch-tui lazydocker")
o.bind("SUPER + SHIFT + G", "Signal", "omarchy-launch-or-focus signal \"uwsm app -- signal-desktop\"")
o.bind("SUPER + SHIFT + O", "Obsidian", "omarchy-launch-or-focus obsidian \"uwsm-app -- obsidian\"")
o.bind("SUPER + SHIFT + slash", "Passwords", "uwsm app -- 1password")

o.bind("SUPER + SHIFT + A", "ChatGPT", "omarchy-launch-webapp \"https://chatgpt.com\"")
o.bind("SUPER + SHIFT + ALT + A", "Grok", "omarchy-launch-webapp \"https://grok.com\"")
o.bind("SUPER + SHIFT + C", "Calendar", "uwsm app -- $HOME/.local/bin/scratchikhal")
o.bind("SUPER + SHIFT + E", "Email", "omarchy-launch-webapp \"https://app.hey.com\"")
o.bind("SUPER + SHIFT + Y", "YouTube", "omarchy-launch-or-focus-webapp YouTube \"https://youtube.com/\"")
o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", "omarchy-launch-or-focus-webapp WhatsApp \"https://web.whatsapp.com/\"")
o.bind("SUPER + SHIFT + CTRL + G", "Google Messages", "omarchy-launch-or-focus-webapp \"Google Messages\" \"https://messages.google.com/web/conversations\"")
o.bind("SUPER + SHIFT + X", "X", "omarchy-launch-webapp \"https://x.com/\"")
o.bind("SUPER + SHIFT + ALT + X", "X Post", "omarchy-launch-webapp \"https://x.com/compose/post\"")

-- Deck — phone sidecar operations
o.bind("SUPER + SHIFT + P", "Deck status", "uwsm app -- xdg-terminal-exec deck status")
o.bind("SUPER + SHIFT + ALT + P", "Deck capture", "uwsm app -- bash -c 'read -p \"Capture: \" t && deck capture \"$t\"'")
o.bind("SUPER + SHIFT + CTRL + P", "Deck push", "uwsm app -- bash -c 'deck phone push-status && deck phone push-contabo'")

-- Volume over 100% (max 150%)
hl.unbind(",XF86AudioRaiseVolume")
hl.unbind(",XF86AudioLowerVolume")
hl.unbind("ALT,XF86AudioRaiseVolume")
hl.unbind("ALT,XF86AudioLowerVolume")
o.bind("XF86AudioRaiseVolume", "Volume up", osdclient .. " --output-volume raise --max-volume 150")
o.bind("XF86AudioLowerVolume", "Volume down", osdclient .. " --output-volume lower --max-volume 150")
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", osdclient .. " --output-volume +1 --max-volume 150")
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", osdclient .. " --output-volume -1 --max-volume 150")

-- Screenshots sem mouse
o.bind("SHIFT + PRINT", "Screenshot fullscreen", "omarchy-capture-screenshot fullscreen")
o.bind("CTRL + PRINT", "Screenshot janela ativa", "bash -c 'W=$(hyprctl activewindow -j); grim -g \"$(echo $W | jq -r \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\")\" - | wl-copy && notify-send \"Screenshot copiado\" -t 2000'")
