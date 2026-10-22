import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking

// Central de controles do sistema: substitui wiremix, bluetui e nmtui dentro do dock.
FocusScope {
    id: view
    required property QtObject theme
    property bool active: false
    property int column: 0
    property var cursor: [0, 0, 0]
    property string message: ""
    property bool messageError: false
    // Bluetooth device or Wi-Fi network we asked to connect; cleared on success, failure or timeout.
    property var pending: null
    function watch(target, name) {
        pending = target; messageError = false
        message = "Connecting to " + name + "…"
        connectTimeout.restart()
    }
    function fail(text) { pending = null; messageError = true; message = text; connectTimeout.stop() }
    function busy(name) { messageError = false; message = name + " is busy, wait for it to finish"; }
    property var askPassword: null
    property var pairTarget: null
    signal back()
    signal helpRequested()
    signal closeRequested()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // Track application streams as well as hardware nodes. Without this, the
    // stream objects are listed but their per-app volume remains unbound.
    PwObjectTracker { objects: Pipewire.nodes.values }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifi: Networking.devices.values.find(function(d) { return d.type === DeviceType.Wifi }) || null
    readonly property var wired: Networking.devices.values.find(function(d) { return d.type === DeviceType.Wired }) || null
    Binding { when: !!view.wifi; target: view.wifi; property: "scannerEnabled"; value: view.active }
    onActiveChanged: { if (!active && adapter && adapter.discovering) adapter.discovering = false; if (!active) askPassword = null }
    Component.onDestruction: { if (adapter && adapter.discovering) adapter.discovering = false }

    function devices(sinks) {
        return Pipewire.nodes.values.filter(function(n) { return n.audio && !n.isStream && n.isSink === sinks })
    }
    // Placas com várias saídas repetem o mesmo prefixo ("500 Series … HDMI 1/2/3"); mostra só o que difere.
    function shortNames(nodes) {
        var words = nodes.map(function(n) { return (n.description || n.nickname || n.name).split(" ") })
        return words.map(function(w) {
            var group = words.filter(function(o) { return o.slice(0, 2).join(" ") === w.slice(0, 2).join(" ") })
            if (group.length < 2) return w.join(" ")
            var k = 0
            while (group.every(function(o) { return k < o.length - 1 && o[k] === w[k] })) k++
            return w.slice(k).join(" ")
        })
    }
    readonly property var audioItems: {
        var items = []
        if (sink) items.push({kind: "volume", node: sink, title: "Output", key: "- + m"})
        if (source) items.push({kind: "volume", node: source, title: "Microphone", key: "- + m"})
        var sinks = devices(true), sinkNames = shortNames(sinks)
        if (sinks.length) items.push({kind: "heading", title: "Output devices"})
        sinks.forEach(function(n, i) { items.push({kind: "sink", node: n, title: sinkNames[i], current: sink === n}) })
        var sources = devices(false), sourceNames = shortNames(sources)
        if (sources.length) items.push({kind: "heading", title: "Input devices"})
        sources.forEach(function(n, i) { items.push({kind: "source", node: n, title: sourceNames[i], current: source === n}) })
        var apps = Pipewire.nodes.values.filter(function(n) { return n.audio && n.isStream && (n.isSink || n.properties["media.class"] === "Stream/Output/Audio") })
        if (apps.length) items.push({kind: "heading", title: "Applications"})
        apps.forEach(function(n) {
            var app = n.properties["application.name"] || n.properties["media.name"] || n.description || n.name
            items.push({kind: "app", node: n, title: app, subtitle: n.description || n.properties["media.role"] || "Application"})
        })
        return items
    }
    readonly property var bluetoothItems: {
        if (!adapter) return []
        var items = [{kind: "bt-power", title: "Bluetooth", on: adapter.enabled, key: "b"}]
        if (!adapter.enabled) return items
        items.push({kind: "bt-scan", title: adapter.discovering ? "Scanning…" : "Scan for devices", on: adapter.discovering, key: "s"})
        var found = Bluetooth.devices.values
            .filter(function(d) { return d.paired || (d.name && d.name !== d.address.replace(/:/g, "-")) })
            .sort(function(a, b) { return (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name) })
        if (found.length) items.push({kind: "heading", title: "Devices"})
        found.forEach(function(d) { items.push({kind: "bt-device", device: d, title: d.name || d.deviceName}) })
        return items
    }
    readonly property var networkItems: {
        var items = wired ? [{kind: "wired", title: "Ethernet", device: wired}] : []
        items.push({kind: "wifi-power", title: "Wi-Fi", on: Networking.wifiEnabled, key: "w"})
        if (wifi && Networking.wifiEnabled && wifi.networks.values.length) items.push({kind: "heading", title: "Networks"})
        if (wifi && Networking.wifiEnabled)
            wifi.networks.values
                .filter(function(n) { return n.name })
                .sort(function(a, b) { return (b.connected - a.connected) || (b.known - a.known) || b.signalStrength - a.signalStrength })
                .forEach(function(n) { items.push({kind: "wifi", network: n, title: n.name}) })
        return items
    }
    readonly property var columns: [audioItems, bluetoothItems, networkItems]
    function current() { var list = columns[column]; return list[Math.min(cursor[column], list.length - 1)] || null }
    function move(delta) {
        var list = columns[column], i = Math.min(cursor[column], list.length - 1) + delta
        while (list[i] && list[i].kind === "heading") i += delta
        if (!list[i]) return
        var c = cursor.slice(); c[column] = i; cursor = c
    }
    function nodeVolume(node) {
        if (!node || !node.audio) return 0
        var values = node.audio.volumes || []
        if (values.length) {
            var total = 0
            values.forEach(function(v) { total += Number(v) || 0 })
            return total / values.length
        }
        return Number(node.audio.volume) || 0
    }
    function setVolume(node, value) {
        if (node && node.audio) {
            var next = Math.max(0, Math.min(1.5, value)); node.audio.muted = false; node.audio.volume = next
            if (node.audio.volumes && node.audio.volumes.length) node.audio.volumes = node.audio.volumes.map(function() { return next })
        }
    }

    function activate(item) {
        if (!item) return
        message = ""
        switch (item.kind) {
        case "volume":
        case "app": item.node.audio.muted = !item.node.audio.muted; break
        case "sink": Pipewire.preferredDefaultAudioSink = item.node; break
        case "source": Pipewire.preferredDefaultAudioSource = item.node; break
        case "bt-power": adapter.enabled = !adapter.enabled; break
        case "bt-scan": adapter.discovering = !adapter.discovering; break
        case "bt-device":
            var d = item.device
            if (d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting) { busy(d.name); break }
            if (d.connected) d.disconnect()
            else if (d.paired) { watch(d, d.name); d.connect() }
            else { pairTarget = d; d.trusted = true; watch(d, d.name); d.pair() }
            break
        case "wifi-power": Networking.wifiEnabled = !Networking.wifiEnabled; break
        case "wired": if (item.device.connected) item.device.disconnect(); break
        case "wifi":
            var n = item.network
            if (n.stateChanging) { busy(n.name); break }
            if (n.connected) n.disconnect()
            else if (n.known || n.security === WifiSecurityType.Open) { watch(n, n.name); n.connect() }
            else askPassword = n
            break
        }
    }

    function volumeTarget() { var item = current(); return item && (item.kind === "volume" || item.kind === "app") ? item.node : sink }
    readonly property var tools: ["wiremix", "bluetui", "nmtui"]
    // Gambito-style keys; the hint next to each control shows its key.
    Keys.onPressed: function(event) {
        var k = event.text, item = current()
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) back()
        else if (k === "?") helpRequested()
        else if (k === "q") closeRequested()
        else if (k === "j" || event.key === Qt.Key_Down) move(1)
        else if (k === "k" || event.key === Qt.Key_Up) move(-1)
        else if (k === "l" || event.key === Qt.Key_Right) column = (column + 1) % 3
        else if (k === "h" || event.key === Qt.Key_Left) column = (column + 2) % 3
        else if (k === "+" || k === "=") { var up = volumeTarget(); if (up) setVolume(up, nodeVolume(up) + 0.05) }
        else if (k === "-") { var down = volumeTarget(); if (down) setVolume(down, nodeVolume(down) - 0.05) }
        else if (k === "m") { var node = volumeTarget(); if (node && node.audio) node.audio.muted = !node.audio.muted }
        else if (k === "b") { if (adapter) adapter.enabled = !adapter.enabled }
        else if (k === "s") { if (adapter && adapter.enabled) adapter.discovering = !adapter.discovering }
        else if (k === "w") Networking.wifiEnabled = !Networking.wifiEnabled
        else if (k === "a") Quickshell.execDetached(["uwsm", "app", "--", "ghostty", "-e", tools[column]])
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activate(item)
        else return
        event.accepted = true
    }

    Connections {
        target: view.pairTarget
        function onPairedChanged() { if (view.pairTarget.paired) { view.pairTarget.connect(); view.pairTarget = null } }
    }
    Connections {
        target: view.askPassword
        function onConnectedChanged() { if (view.askPassword && view.askPassword.connected) { view.askPassword = null; view.forceActiveFocus() } }
    }
    Connections {
        target: view.pending
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            if (!view.pending || !view.pending.connected) return
            view.message = "Connected to " + view.pending.name
            view.pending = null
            connectTimeout.stop()
            clearMessage.restart()
        }
        // Wi-Fi only; Bluetooth has no failure signal, so it relies on the timeout.
        function onConnectionFailed(reason) { view.fail("Connection failed: " + ConnectionFailReason.toString(reason) + " · Enter to retry") }
    }
    Timer { id: connectTimeout; interval: 20000; onTriggered: { if (view.pending) view.fail("Couldn't connect to " + view.pending.name + " · Enter to retry") } }
    Timer { id: clearMessage; interval: 3000; onTriggered: { if (!view.pending && !view.messageError) view.message = "" } }

    ColumnLayout {
        anchors.fill: parent; spacing: 10
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            visible: false
            Repeater {
                model: [
                    {title: "Audio", tool: "wiremix"},
                    {title: "Bluetooth", tool: "bluetui"},
                    {title: "Network", tool: "nmtui"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; height: 38; radius: 7
                    color: view.column === index ? Qt.alpha(theme.accent, 0.16) : Qt.alpha(theme.foreground, 0.035)
                    border.color: view.column === index ? Qt.alpha(theme.accent, 0.6) : Qt.alpha(theme.foreground, 0.12)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Text { anchors.centerIn: parent; text: modelData.title + "   " + (index + 1); color: theme.foreground; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: { view.column = index; view.forceActiveFocus() } }
                }
            }
        }
        Repeater {
            model: [
                {title: "Audio", tool: "wiremix", empty: "PipeWire unavailable"},
                {title: "Bluetooth", tool: "bluetui", empty: "No Bluetooth adapter"},
                {title: "Network", tool: "nmtui", empty: "NetworkManager unavailable"}
            ]
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool focused: view.column === index
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: focused
                radius: 9
                color: Qt.alpha(theme.foreground, 0.035)
                border.color: focused ? Qt.alpha(theme.accent, 0.55) : Qt.alpha(theme.foreground, 0.12)
                Behavior on border.color { ColorAnimation { duration: 140 } }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 8
                    RowLayout {
                        Text { Layout.fillWidth: true; text: card.modelData.title; color: theme.foreground; font.pixelSize: 16 }
                        Text {
                            text: "advanced  a"; color: theme.foreground; opacity: 0.5; font.pixelSize: 10
                            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["uwsm", "app", "--", "ghostty", "-e", card.modelData.tool]) }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
                    ListView {
                        id: list
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 2
                        model: view.columns[card.index]
                        currentIndex: view.cursor[card.index]
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool selected: card.focused && view.cursor[card.index] === index
                            readonly property var node: modelData.node || null
                            readonly property var device: modelData.device || null
                            readonly property var network: modelData.network || null
                            readonly property bool heading: modelData.kind === "heading"
                            width: list.width
                            height: heading ? 26 : (modelData.kind === "volume" || modelData.kind === "app") ? 62 : view.askPassword && view.askPassword === network ? 82 : 46
                            radius: 6
                            color: selected ? Qt.alpha(theme.accent, 0.13) : hover.containsMouse ? Qt.alpha(theme.foreground, 0.05) : "transparent"
                            border.color: selected ? Qt.alpha(theme.accent, 0.4) : "transparent"
                            Text {
                                visible: row.heading; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                text: row.modelData.title; color: theme.foreground; opacity: 0.5; font.pixelSize: 11
                            }
                            MouseArea {
                                id: hover
                                enabled: !row.heading
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: { var c = view.cursor.slice(); c[card.index] = row.index; view.cursor = c; view.column = card.index; view.forceActiveFocus(); view.activate(row.modelData) }
                            }
                            ColumnLayout {
                                visible: !row.heading
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.topMargin: 6; anchors.bottomMargin: 6
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text {
                                        Layout.preferredWidth: 16
                                        text: row.modelData.current || (row.device && row.device.connected) || (row.network && row.network.connected) || (row.modelData.kind === "wired" && row.device.connected) ? "●" : row.modelData.on === true ? "●" : "○"
                                        color: text === "●" ? theme.accent : theme.foreground; opacity: text === "●" ? 1 : 0.45; font.pixelSize: 11
                                    }
                                    Text { Layout.fillWidth: true; text: row.modelData.title + (row.modelData.subtitle ? " · " + row.modelData.subtitle : ""); textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 13 }
                                    Text { visible: !!row.modelData.key; text: row.modelData.key || ""; color: theme.foreground; opacity: 0.4; font.family: "monospace"; font.pixelSize: 10 }
                                    Text {
                                        color: theme.foreground; opacity: 0.6; font.pixelSize: 11; font.family: row.modelData.kind === "wifi" ? theme.font : Qt.application.font.family
                                        text: {
                                            var m = row.modelData
                                            if (m.kind === "volume" || m.kind === "app") return row.node.audio ? (row.node.audio.muted ? "muted" : Math.round(view.nodeVolume(row.node) * 100) + "%") : ""
                                            if (m.kind === "bt-power" || m.kind === "wifi-power") return m.on ? "on" : "off"
                                            if (m.kind === "bt-device") return row.device.pairing ? "pairing…" : row.device.state === BluetoothDeviceState.Connecting ? "connecting…" : row.device.connected ? (row.device.batteryAvailable ? Math.round(row.device.battery * 100) + "% · " : "") + "connected" : row.device.paired ? "paired" : "new"
                                            if (m.kind === "wifi") return row.network.stateChanging ? "connecting…" : (row.network.connected ? "connected · " : row.network.known ? "saved · " : row.network.security === WifiSecurityType.Open ? "open  " : "󰌾  ") + ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor((row.network.signalStrength > 1 ? row.network.signalStrength / 100 : row.network.signalStrength) * 4))]
                                            if (m.kind === "wired") return row.device.connected ? "connected" : "unplugged"
                                            if (m.kind === "sink" || m.kind === "source") return m.current ? "default" : ""
                                            return ""
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: row.modelData.kind === "volume" || row.modelData.kind === "app"
                                    Layout.fillWidth: true; Layout.leftMargin: 24; height: 6; radius: 3
                                    color: Qt.alpha(theme.foreground, 0.12)
                                    Rectangle {
                                        width: parent.width * (row.node && row.node.audio ? Math.min(1, view.nodeVolume(row.node)) : 0); height: parent.height; radius: 3
                                        color: row.node && row.node.audio && row.node.audio.muted ? Qt.alpha(theme.foreground, 0.35) : view.nodeVolume(row.node) > 1 ? theme.error : theme.accent
                                        Behavior on width { NumberAnimation { duration: 90 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -8
                                        function apply(mouse) { view.setVolume(row.node, (mouse.x - 8) / (width - 16)) }
                                        onPressed: function(mouse) { apply(mouse) }
                                        onPositionChanged: function(mouse) { if (pressed) apply(mouse) }
                                    }
                                }
                                Rectangle {
                                    visible: !!view.askPassword && view.askPassword === row.network
                                    Layout.fillWidth: true; Layout.leftMargin: 24; height: 30; radius: 5
                                    color: theme.background; border.color: theme.accent
                                    onVisibleChanged: { if (visible) { passwordInput.text = ""; passwordInput.forceActiveFocus() } }
                                    TextInput {
                                        id: passwordInput
                                        anchors.fill: parent; anchors.margins: 7
                                        echoMode: TextInput.Password; color: theme.foreground; font.pixelSize: 12; clip: true
                                        Text { visible: !parent.text; text: "Network password · Enter to connect"; color: theme.foreground; opacity: 0.5; font.pixelSize: 12 }
                                        Keys.onReturnPressed: { if (text) { view.watch(row.network, row.network.name); row.network.connectWithPsk(text) } }
                                        Keys.onEnterPressed: { if (text) { view.watch(row.network, row.network.name); row.network.connectWithPsk(text) } }
                                        Keys.onEscapePressed: { view.askPassword = null; view.forceActiveFocus() }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !list.count; Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: card.modelData.empty; color: theme.foreground; opacity: 0.55; font.pixelSize: 12
                    }
                    Text {
                        visible: view.message !== "" && card.index > 0
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: view.message
                        color: view.messageError ? theme.error : theme.foreground
                        opacity: view.messageError ? 1 : 0.7
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
