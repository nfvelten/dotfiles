-- Compatibility entrypoint for sessions that still invoke hyprland.lua.
-- New sessions use ~/.config/hypr/hyprland.conf.

hl.config({
  input = {
    kb_layout = "br",
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})

local function bind(key, description, command)
  hl.unbind(key)
  hl.bind(key, hl.dsp.exec_cmd(command), { description = description })
end

bind("SUPER + SPACE", "Main menu", "$HOME/.local/bin/walker-main")
bind("SUPER + SHIFT + SPACE", "Toggle bar", "pkill -USR1 -x waybar")
bind("SUPER + RETURN", "Terminal", "ghostty")
bind("SUPER + ALT + RETURN", "Tmux", "ghostty -e tmux new-session -A -s main")
bind("SUPER + CTRL + RETURN", "Herdr", "$HOME/.local/bin/scratchherdr")
bind("SUPER + SHIFT + RETURN", "Browser", "librewolf")
bind("SUPER + grave", "Scratchpad terminal", "$HOME/.local/bin/scratchterm")
bind("SUPER + CTRL + grave", "Window switcher", "walker -m windows")
bind("SUPER + B", "Browser", "librewolf")
bind("SUPER + SHIFT + B", "Browser", "librewolf")
bind("SUPER + SHIFT + ALT + B", "Private browser", "librewolf --private-window")
bind("SUPER + SHIFT + F", "Files", "ghostty -e yazi")
bind("SUPER + N", "Nvim", "$HOME/.local/bin/scratchnvim")
bind("SUPER + E", "Work nvim", "$HOME/.local/bin/scratchwork")
bind("SUPER + H", "Keybindings", "$HOME/.local/bin/scratchkeys")
bind("SUPER + R", "Meeting record", "$HOME/.local/bin/meeting-record")
bind("SUPER + SHIFT + N", "Editor", "ghostty -e nvim")
bind("SUPER + SHIFT + T", "Activity", "ghostty -e btop")
bind("SUPER + SHIFT + O", "Org", "ghostty -e emacsclient -nw ~/org/inbox.org")
bind("SUPER + SHIFT + M", "Spotify", "spotify")
bind("SUPER + C", "Herdr", "$HOME/.local/bin/scratchherdr")

hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.window.close(), { description = "Close window" })
hl.unbind("SUPER + Q")
bind("SUPER + F", "Fullscreen", "hyprctl dispatch fullscreen")
bind("SUPER + T", "Toggle floating", "hyprctl dispatch togglefloating")
bind("SUPER + LEFT", "Focus left", "hyprctl dispatch movefocus l")
bind("SUPER + RIGHT", "Focus right", "hyprctl dispatch movefocus r")
bind("SUPER + UP", "Focus up", "hyprctl dispatch movefocus u")
bind("SUPER + DOWN", "Focus down", "hyprctl dispatch movefocus d")
bind("SUPER + SHIFT + LEFT", "Move left", "hyprctl dispatch movewindow l")
bind("SUPER + SHIFT + RIGHT", "Move right", "hyprctl dispatch movewindow r")
bind("SUPER + SHIFT + UP", "Move up", "hyprctl dispatch movewindow u")
bind("SUPER + SHIFT + DOWN", "Move down", "hyprctl dispatch movewindow d")
bind("SUPER + J", "Focus down", "hyprctl dispatch movefocus d")
bind("SUPER + K", "Focus up", "hyprctl dispatch movefocus u")
bind("SUPER + L", "Focus right", "hyprctl dispatch movefocus r")

for i = 1, 5 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }),
    { description = "Workspace " .. i })
  hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }),
    { description = "Move to workspace " .. i })
end

bind("SUPER + CTRL + L", "Lock screen", "hyprlock")
bind("SUPER + CTRL + W", "Network", "ghostty -e nmtui")
bind("SUPER + CTRL + B", "Bluetooth", "ghostty -e bluetui")
bind("SUPER + CTRL + A", "Audio", "ghostty -e wiremix")
bind("SUPER + CTRL + X", "Power menu", "$HOME/.local/bin/desktop-power")
bind("SUPER + ESCAPE", "Power menu", "$HOME/.local/bin/desktop-power")
bind("SUPER + CTRL + P", "Power menu", "$HOME/.local/bin/desktop-power")
bind("SUPER + CTRL + V", "Clipboard", "$HOME/.local/bin/desktop-clipboard")
bind("SUPER + comma", "Dismiss notification", "makoctl dismiss")
bind("SUPER + SHIFT + comma", "Dismiss notifications", "makoctl dismiss --all")
bind("SUPER + SHIFT + P", "Deck status", "ghostty -e deck status")
bind("SUPER + SHIFT + ALT + P", "Deck capture", "ghostty -e bash -lc 'read -p \"Capture: \" t && deck capture \"$t\"'")
bind("SUPER + SHIFT + CTRL + P", "Deck push", "ghostty -e bash -lc 'deck phone push-status && deck phone push-contabo'")
bind("SUPER + F10", "Color picker", "pkill hyprpicker || hyprpicker -a")
bind("F10", "Screenshot region", "$HOME/.local/bin/desktop-screenshot")
bind("PRINT", "Screenshot region", "$HOME/.local/bin/desktop-screenshot")
bind("SHIFT + PRINT", "Screenshot fullscreen", "$HOME/.local/bin/desktop-screenshot full")
