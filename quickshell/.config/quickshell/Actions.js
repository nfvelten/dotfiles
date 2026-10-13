.pragma library

function all() {
    return [
        { title: "Dashboard", icon: "go-home", keywords: "home overview feed today", route: "main" },
        { title: "Music", icon: "audio-x-generic", keywords: "spotify player playlists queue recent", route: "media" },
        { title: "Calendar", icon: "x-office-calendar", keywords: "agenda events khal ical", route: "calendar" },
        { title: "tmux sessions", icon: "utilities-terminal", keywords: "terminal agents work windows", route: "tmux" },
        { title: "Org notes", icon: "accessories-text-editor", keywords: "orgmode notes emacs agenda", route: "notes" },
        { title: "Oikos", icon: "video-display", keywords: "homelab movies films games downloads tv media", command: "uwsm app -- ghostty -e oikos" },
        { title: "Applications", icon: "view-app-grid", keywords: "apps launch programs", route: "applications" },
        { title: "Audio", icon: "audio-volume-high-symbolic", keywords: "sound volume mixer som microfone", route: "audio" },
        { title: "Bluetooth", icon: "bluetooth", keywords: "devices wireless fone", route: "bluetooth" },
        { title: "Clipboard", icon: "edit-paste", keywords: "history paste", route: "clipboard" },
        { title: "Emacs", icon: "emacs", keywords: "org elfeed editor", command: "emacsclient --socket-name=default -c -n" },
        { title: "File manager", icon: "folder", keywords: "files yazi", command: "uwsm app -- ghostty -e yazi" },
        { title: "Network", icon: "network-wireless-signal-excellent-symbolic", keywords: "wifi internet rede", route: "network" },
        { title: "Neovim", icon: "nvim", keywords: "nvim editor code", command: "uwsm app -- $HOME/.local/bin/scratchnvim" },
        { title: "Notifications", icon: "preferences-system-notifications-symbolic", keywords: "history alerts do not disturb", route: "notifications" },
        { title: "Dock preferences", icon: "preferences-system-symbolic", keywords: "settings buttons top bar tmux morph", route: "preferences" },
        { title: "Power", icon: "system-shutdown", keywords: "shutdown reboot suspend", route: "power" },
        { title: "Radiola", icon: "audio-headphones", keywords: "podcast podcasts audio episodes feeds listen", command: "uwsm app -- $HOME/.local/bin/radiola-ui" },
        { title: "Lock", icon: "system-lock-screen-symbolic", keywords: "lock screen", command: "loginctl lock-session" }
    ]
}

function power() {
    return [
        { title: "Lock", icon: "system-lock-screen-symbolic", command: "loginctl lock-session" },
        { title: "Suspend", icon: "weather-clear-night-symbolic", command: "systemctl suspend" },
        { title: "Reboot", icon: "system-reboot", command: "systemctl reboot", confirm: true },
        { title: "Power off", icon: "system-shutdown", command: "systemctl poweroff", confirm: true }
    ]
}
