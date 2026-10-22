//@ pragma IconTheme Yaru
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    Theme { id: palette }
    Settings {
        id: preferences
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/yerba-shell.ini"
        category: "desktop"
        property bool showTopBar: false
        property bool showButtons: true
        property bool tmuxMorph: true
        property bool showKeyHints: true
        property bool showAgentsCard: true
        property bool showGambitoCard: true
        property bool showNotificationsCard: true
        property bool showEventsCard: true
        property bool showMediaCard: true
        property bool showPodcastCard: true
        property bool showTasksCard: true
        property bool showAzureCard: true
        property bool showIdleCard: true
        // Off-work suggestions: always, only outside work hours, or never.
        property string idleSuggestionsMode: "off-work"
        // Dashboard layout: comma-separated card names. Empty order = sort by urgency.
        property string cardOrder: ""
        property string collapsedCards: ""
    }
    function toggleTopBar() {
        preferences.showTopBar = !preferences.showTopBar
        preferences.sync()
    }
    property bool menuOpen: false
    property bool keyHintsVisible: false
    property string now: Qt.formatDateTime(new Date(), "ddd HH:mm")

    Lock { id: lockScreen; theme: palette }
    KeyHints { id: keyHints; theme: palette; time: root.now; statusVisible: !preferences.showTopBar && !root.menuOpen; shown: root.keyHintsVisible && preferences.showKeyHints }

    // Any compositor-level navigation (Super + C scratchpad, workspace switch, new window) dismisses the dock.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activespecial", "workspace", "workspacev2", "openwindow", "closewindow", "movewindow", "activewindow", "fullscreen", "changefloatingmode", "urgent"].indexOf(event.name) >= 0) root.keyHintsVisible = false
            // "special:NAME,MONITOR" when a scratchpad shows, ",MONITOR" when it hides.
            if (event.name === "activespecial") root.visibleSpecial = event.data.split(",")[0].replace(/^special:/, "")
            // Ignore the scratchpad we hide ourselves while the dock morphs out of it.
            if (event.name === "activespecial" && Date.now() < root.ignoreSpecialUntil) return
            if (root.menuOpen && ["activespecial", "workspace", "openwindow"].indexOf(event.name) >= 0) root.menuOpen = false
        }
    }

    // Dock <-> scratchpad morphs. The dock and every scratchpad (Super + C, Super + Shift + O…) swap
    // with the same animation: the dock's rect travels to/from the window's real geometry and the
    // scratchpad toggles underneath without Hyprland's slide (hypr-toggle-special --no-anim).
    property string visibleSpecial: ""
    property bool transitioningSpecial: false
    property double ignoreSpecialUntil: 0
    readonly property string toggleSpecial: Quickshell.env("HOME") + "/.local/bin/hypr-toggle-special"
    Process {
        id: specialProbe
        command: ["bash", "-c", "hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name | sub(\"^special:\"; \"\")'"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.visibleSpecial = text.trim() }
    }
    Process {
        id: geometry
        property var callback: null
        // The scratchpad window's rect, relative to the focused monitor (null when it doesn't exist yet).
        command: ["bash", "-c", "jq -n --argjson c \"$(hyprctl clients -j)\" --argjson m \"$(hyprctl monitors -j)\" --arg ws \"special:$1\" 'first(($m[] | select(.focused)) as $mon | $c[] | select(.workspace.name == $ws) | {x: (.at[0] - $mon.x), y: (.at[1] - $mon.y), w: .size[0], h: .size[1]}) // null'", "geometry", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                var rect = null
                try { rect = JSON.parse(text) } catch (e) {}
                if (geometry.callback) geometry.callback(rect)
            }
        }
    }
    function withGeometry(name, callback) {
        if (geometry.running) return
        geometry.callback = callback
        geometry.command = geometry.command.slice(0, 4).concat([name])  // bash -c SCRIPT $0 $1
        geometry.running = true
    }
    // Scratchpad visible -> the dock appears opaque exactly over its window (layer fade off, so
    // there is no half-transparent frame), the scratchpad hides underneath without its slide,
    // and after a short hold the dock shrinks into place.
    property string layersRestore: ""
    Process {
        id: layersOff
        property var rect: null
        property string name: ""
        command: [Quickshell.env("HOME") + "/.local/bin/hypr-animation-off", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.layersRestore = text.trim()
                root.ignoreSpecialUntil = Date.now() + 1500
                menu.morphFrom(layersOff.rect)
                root.menuOpen = true
                hideSpecial.command = [root.toggleSpecial, "--no-anim", layersOff.name]
                hideDelay.restart()
            }
        }
    }
    Timer { id: hideDelay; interval: 50; onTriggered: hideSpecial.running = true }
    Process {
        id: hideSpecial
        onExited: {
            if (root.layersRestore) Quickshell.execDetached(["hyprctl", "eval", root.layersRestore])
            root.layersRestore = ""
            holdTimer.restart()
        }
    }
    Timer { id: holdTimer; interval: 120; onTriggered: menu.morphRelease() }
    Timer {
        id: switchSpecialDelay
        interval: 430
        property string target: ""
        onTriggered: { if (target) root.morphToSpecial(target); target = "" }
    }
    Timer {
        id: switchSpecialCleanup
        interval: 900
        onTriggered: { menu.transitionOnly = false; root.transitioningSpecial = false }
    }
    Timer {
        id: morphCloseDelay
        // Dá tempo para o Hyprland apresentar a janela destino antes de
        // remover a camada fullscreen que fornece o blur.
        interval: 320
        onTriggered: root.menuOpen = false
    }
    function switchSpecial(name) {
        if (!name || name === visibleSpecial) return
        if (!menuOpen && visibleSpecial) {
            // Morph entre os retângulos dos scratchpads, com o conteúdo da
            // main dock coberto durante a transição.
            menu.transitionOnly = true
            root.transitioningSpecial = true
            switchSpecialDelay.target = name
            openMenu()
            switchSpecialDelay.restart()
            switchSpecialCleanup.restart()
            return
        }
        morphToSpecial(name)
    }
    function openMenu() {
        if (menuOpen) return
        var name = visibleSpecial
        if (!name) { menuOpen = true; return }
        withGeometry(name, function(rect) {
            if (!rect) { root.ignoreSpecialUntil = Date.now() + 1500; root.menuOpen = true; Quickshell.execDetached([root.toggleSpecial, name]); return }
            layersOff.rect = rect
            layersOff.name = name
            layersOff.running = true
        })
    }
    // Dock open + a scratchpad shortcut (handed over by hypr-toggle-special) -> the dock grows into it.
    function morphToSpecial(name) {
        if (!menuOpen) { Quickshell.execDetached([toggleSpecial, name]); return }
        withGeometry(name, function(rect) {
            // Preserve o painel de blur até o fim do morph; o evento
            // activespecial do Hyprland chega antes da janela de destino.
            root.ignoreSpecialUntil = Date.now() + 1200
            if (rect) menu.morphInto(rect, function() {
                Quickshell.execDetached(["env", "YERBA_DIRECT_SWITCH=1", root.toggleSpecial, "--no-anim", name])
                morphCloseDelay.restart()
            })
            else { root.menuOpen = false; Quickshell.execDetached(["bash", "-c", "sleep 0.15; exec \"$0\" \"$1\"", root.toggleSpecial, name]) }
        })
    }

    IpcHandler {
        target: "yerba"
        function status(): string {
            return JSON.stringify({
                requested: root.menuOpen,
                open: menu.isOpen,
                visible: menu.visible,
                route: menu.route,
                results: menu.rows.length,
                topBar: preferences.showTopBar,
                dockStatus: menu.isOpen && !preferences.showTopBar,
                keyHints: root.keyHintsVisible,
                visibleSpecial: root.visibleSpecial,
                morph: menu.morph
            })
        }
        function toggleTopBar() { root.toggleTopBar() }
        function toggleMenu() {
            if (root.menuOpen && menu.route === "power") { menu.route = "main"; return }
            if (root.menuOpen) root.menuOpen = false
            else root.openMenu()
        }
        function clipboardMenu() { menu.route = "clipboard"; root.openMenu() }
        function powerMenu() { menu.route = "power"; root.openMenu() }
        function lock() { root.menuOpen = false; lockScreen.locked = true }
        function closeMenu() { root.menuOpen = false }
        function showKeys() { root.keyHintsVisible = true }
        function hideKeys() { root.keyHintsVisible = false }
        function controls() { menu.openControls(0); root.openMenu() }
        function mediaMenu() {
            root.keyHintsVisible = false
            if (root.menuOpen && menu.route === "media") root.menuOpen = false
            else { menu.route = "media"; root.openMenu() }
        }
        function open(route: string) { menu.navigate(route); root.openMenu() }
        // From desktop-pass: field names (never values) of a decrypted entry.
        // Names arrive tab-separated with "," and "%" percent-encoded (the CLI splits on commas).
        function passFields(entry: string, names: string) { menu.showPassFields(decodeURIComponent(entry), names.split("\t").map(decodeURIComponent)); root.openMenu() }
        function morphTo(name: string) { root.morphToSpecial(name) }
        function switchSpecial(name: string) { root.switchSpecial(name) }
    }

    Notifications { id: notificationService; theme: palette; paused: lockScreen.locked || root.menuOpen }
    Osd { theme: palette }
    Meeting { id: meetingMode; notifications: notificationService }
    Clipboard { id: clipboardStore }
    Yerbad { id: yerbadService }
    OrgStore { id: orgStore; yerbad: yerbadService }
    // Spotify is visible only on the dashboard and Music page. Avoid polling
    // the Web API while the dock is closed or another route is active.
    MediaStore { id: mediaStore; yerbad: yerbadService; active: root.menuOpen && (menu.route === "main" || menu.route === "media") }
    Feed { id: feedStore; yerbad: yerbadService; theme: palette; org: orgStore; notifications: notificationService; media: mediaStore; preferences: preferences; open: root.menuOpen; boardsOpen: root.menuOpen && menu.route === "boards" }
    Bar {
        visible: preferences.showTopBar
        theme: palette
        time: root.now
        onMenuRequested: root.menuOpen = !root.menuOpen
        onControlsRequested: function(column) { menu.openControls(column); root.openMenu() }
    }
    Menu {
        id: menu
        org: orgStore
        meeting: meetingMode
        yerbad: yerbadService
        showTopBar: preferences.showTopBar
        buttonPreferences: preferences
        time: root.now
        onToggleTopBarRequested: root.toggleTopBar()
        clipboard: clipboardStore
        notifications: notificationService
        feed: feedStore
        media: mediaStore
        theme: palette
        isOpen: root.menuOpen
        onCloseRequested: root.menuOpen = false
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: now = Qt.formatDateTime(new Date(), "ddd HH:mm")
    }
}
