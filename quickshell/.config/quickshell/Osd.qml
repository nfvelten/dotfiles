import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Transient pill at the top centre: volume, mic, brightness and power changes.
// Audio is read from PipeWire state, so keys, the dock panel and wiremix all show it.
Scope {
    id: osd
    required property QtObject theme
    property string icon: ""
    property string label: ""
    property real level: -1  // 0..1.5 shows a bar; -1 hides it
    property bool warn: false
    property bool shown: false

    function show(icon, label, level, warn) {
        if (!armed.done) return
        osd.icon = icon; osd.label = label; osd.level = level; osd.warn = !!warn
        shown = true
        hideTimer.restart()
    }
    // PipeWire and UPower settle after startup; ignore that first burst.
    Timer { id: armed; property bool done: false; interval: 2000; running: true; onTriggered: done = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: osd.shown = false }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    function showVolume() {
        var pct = Math.round(volume * 100)
        show(sinkMuted ? "󰖁" : pct < 34 ? "󰕿" : pct < 67 ? "󰖀" : "󰕾", sinkMuted ? "Muted" : pct + "%", sinkMuted ? 0 : volume, volume > 1)
    }
    onVolumeChanged: showVolume()
    onSinkMutedChanged: showVolume()
    onMicMutedChanged: show(micMuted ? "󰍭" : "󰍬", micMuted ? "Mic muted" : "Mic on", -1, micMuted)
    onSinkChanged: { if (sink) show("󰓃", sink.description || sink.nickname || sink.name || "Output", -1) }

    // sysfs has no change events, and Dell firmware may change the backlight without
    // any key reaching Hyprland, so poll the value (a tiny read) and show it on change.
    property string backlight: ""
    property int maxBrightness: 0
    property int lastBrightness: -1
    Process {
        running: true
        command: ["sh", "-c", "d=$(ls -d /sys/class/backlight/* | head -1); echo \"$d $(cat $d/max_brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                osd.maxBrightness = parseInt(parts[1]) || 0
                osd.backlight = osd.maxBrightness ? parts[0] + "/actual_brightness" : ""
            }
        }
    }
    FileView {
        id: brightnessFile
        path: osd.backlight
        onLoaded: {
            var value = parseInt(text())
            if (isNaN(value) || value === osd.lastBrightness) return
            var first = osd.lastBrightness < 0
            osd.lastBrightness = value
            if (first) return
            var pct = Math.round(value * 100 / osd.maxBrightness)
            osd.show(pct < 34 ? "󰃞" : pct < 67 ? "󰃟" : "󰃠", pct + "%", pct / 100)
        }
    }
    Timer { interval: 200; running: osd.backlight !== ""; repeat: true; onTriggered: brightnessFile.reload() }

    readonly property var battery: UPower.displayDevice
    readonly property bool onBattery: UPower.onBattery
    readonly property int batteryPct: battery && battery.ready ? Math.round(battery.percentage * 100) : 100
    property int lastAlert: 101
    onOnBatteryChanged: {
        if (!battery || !battery.isPresent) return
        show(onBattery ? "󰂃" : "󰂄", (onBattery ? "On battery · " : "Charging · ") + batteryPct + "%", -1)
        if (!onBattery) lastAlert = 101
    }
    // One notification per threshold crossed while discharging; it stays in history.
    onBatteryPctChanged: {
        if (!onBattery || !battery.isPresent) return
        var steps = [5, 10, 20]
        for (var i = 0; i < steps.length; i++) {
            if (batteryPct <= steps[i] && lastAlert > steps[i]) {
                lastAlert = steps[i]
                Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", steps[i] <= 10 ? "critical" : "normal", "-i", "battery-caution", "Battery low · " + batteryPct + "%", "Plug in the charger"])
                return
            }
        }
    }

    IpcHandler {
        target: "osd"
        function test() { osd.show("󰕾", "OSD test", 0.42) }
    }

    PanelWindow {
        visible: osd.shown || pill.opacity > 0
        anchors.top: true
        margins.top: 10
        implicitWidth: 260
        implicitHeight: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "yerba-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            height: parent.height
            width: osd.shown ? parent.width : parent.height
            radius: height / 2
            color: osd.theme.background
            border.width: 1
            border.color: osd.warn ? osd.theme.error : osd.theme.border
            opacity: osd.shown ? 1 : 0
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            clip: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.right: parent.right; anchors.rightMargin: 16
                spacing: 12
                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.icon
                    color: osd.warn ? osd.theme.error : osd.theme.accent
                    font.family: osd.theme.font; font.pixelSize: 18
                }
                Rectangle {
                    visible: osd.level >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - glyph.width - labelText.width - 24
                    height: 6; radius: 3
                    color: Qt.alpha(osd.theme.foreground, 0.15)
                    Rectangle {
                        height: parent.height; radius: 3
                        width: parent.width * Math.min(1, Math.max(0, osd.level))
                        color: osd.warn ? osd.theme.error : osd.theme.accent
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    id: labelText
                    anchors.verticalCenter: parent.verticalCenter
                    width: osd.level >= 0 ? 44 : parent.width - glyph.width - parent.spacing
                    horizontalAlignment: osd.level >= 0 ? Text.AlignRight : Text.AlignLeft
                    text: osd.label
                    elide: Text.ElideRight
                    color: osd.theme.foreground
                    font.family: osd.theme.font; font.pixelSize: 13
                }
            }
        }
    }
}
