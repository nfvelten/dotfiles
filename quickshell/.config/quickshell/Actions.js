.pragma library

function all() {
    return [
        { title: "Applications", keywords: "apps launch programs", command: "walker" },
        { title: "Audio", keywords: "sound volume mixer", command: "uwsm app -- ghostty -e wiremix" },
        { title: "Bluetooth", keywords: "devices wireless", command: "uwsm app -- ghostty -e bluetui" },
        { title: "Clipboard", keywords: "history paste", command: "walker -m clipboard" },
        { title: "Emacs", keywords: "org elfeed editor", command: "emacsclient --socket-name=default -c -n" },
        { title: "File manager", keywords: "files yazi", command: "uwsm app -- ghostty -e yazi" },
        { title: "Network", keywords: "wifi internet", command: "uwsm app -- ghostty -e nmtui" },
        { title: "Neovim", keywords: "nvim editor code", command: "uwsm app -- $HOME/.local/bin/scratchnvim" },
        { title: "Notifications", keywords: "history alerts do not disturb", route: "notifications" },
        { title: "Power", keywords: "shutdown reboot suspend", route: "power" },
        { title: "Lock", keywords: "lock screen", command: "loginctl lock-session" }
    ]
}

function power() {
    return [
        { title: "Lock", command: "hyprlock" },
        { title: "Suspend", command: "systemctl suspend" },
        { title: "Reboot", command: "systemctl reboot", confirm: true },
        { title: "Power off", command: "systemctl poweroff", confirm: true }
    ]
}
