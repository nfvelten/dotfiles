-- User session services and desktop processes.

---@module 'hl'

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP DESKTOP_SESSION")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP DESKTOP_SESSION")
    -- Polkit prompts come from quickshell (Polkit.qml); hyprpolkitagent stays disabled.
    hl.exec_cmd("systemctl --user start quickshell.service")
    hl.exec_cmd("systemctl --user restart desktop-wallpaper.service")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprsunset")
    -- Media keys (playerctl) follow the most recently active player.
    hl.exec_cmd("playerctld daemon")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("fcitx5 -d")
end)
