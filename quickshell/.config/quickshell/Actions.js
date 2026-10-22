.pragma library

function all() {
    return [
        { title: "Dashboard", icon: "go-home", keywords: "home overview feed today", route: "main" },
        { title: "Media", icon: "audio-x-generic", keywords: "music spotify player playlists queue recent video browser", route: "media" },
        { title: "Calendar", icon: "x-office-calendar", keywords: "agenda events khal ical", route: "calendar" },
        { title: "tmux sessions", icon: "utilities-terminal", keywords: "terminal agents work windows", route: "tmux" },
        { title: "Org notes", icon: "accessories-text-editor", keywords: "orgmode notes emacs agenda", route: "notes" },
        { title: "Oikos", icon: "video-display", keywords: "homelab movies films games downloads tv media", command: "uwsm app -- ghostty -e oikos" },
        { title: "Applications", icon: "view-app-grid", keywords: "apps launch programs", route: "applications" },
        { title: "Audio", icon: "audio-volume-high-symbolic", keywords: "sound volume mixer som microfone", route: "audio" },
        { title: "Bluetooth", icon: "bluetooth", keywords: "devices wireless fone", route: "bluetooth" },
        { title: "Passwords", icon: "dialog-password", keywords: "pass password senha login credentials", route: "passwords" },
        { title: "Clipboard", icon: "edit-paste", keywords: "history paste", route: "clipboard" },
        { title: "Read QR code from screen", icon: "edit-find", keywords: "qr barcode pix wifi 2fa otp scan", command: "sleep 0.35; $HOME/.local/bin/desktop-qr read" },
        { title: "Show clipboard as QR code", icon: "edit-paste", keywords: "qr phone send link share", command: "$HOME/.local/bin/desktop-qr show" },
        { title: "Share Wi-Fi as QR code", icon: "network-wireless-signal-excellent-symbolic", keywords: "qr wifi password guest share", command: "$HOME/.local/bin/desktop-qr wifi" },
        { title: "Copy text from screen", icon: "edit-find", keywords: "ocr extract text region tesseract", command: "sleep 0.35; $HOME/.local/bin/desktop-ocr" },
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
