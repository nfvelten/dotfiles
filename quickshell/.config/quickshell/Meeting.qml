import QtQuick
import Quickshell
import Quickshell.Io

// Meeting mode: DND plus an idle/sleep inhibitor for N minutes, then the previous DND state
// comes back. The muted-mic icon on the status strip covers the "am I muted?" part.
Scope {
    id: meeting
    required property QtObject notifications
    property double until: 0
    readonly property bool active: until > 0
    // DND state from before the meeting, restored when it ends.
    property bool hadDnd: false
    property double hadDndUntil: 0

    function start(minutes) {
        if (!active) { hadDnd = notifications.dnd; hadDndUntil = notifications.dndUntil }
        until = Date.now() + minutes * 60000
        notifications.snoozeDnd(minutes)
        inhibitor.running = false
        inhibitor.command = ["systemd-inhibit", "--what=idle:sleep", "--who=Yerba", "--why=Meeting mode", "--mode=block", "sleep", String(minutes * 60)]
        inhibitor.running = true
    }
    function stop() {
        if (!active) return
        until = 0
        inhibitor.running = false
        // A timed DND that would have expired during the meeting stays off.
        notifications.setDnd(hadDnd && (hadDndUntil === 0 || hadDndUntil > Date.now()), hadDndUntil)
        Quickshell.execDetached(["notify-send", "-a", "Meeting mode", "Meeting mode ended", "Notifications and sleep are back to normal"])
    }
    Process { id: inhibitor }
    Timer {
        interval: 15000; repeat: true; running: meeting.active
        onTriggered: { if (Date.now() >= meeting.until) meeting.stop() }
    }
    IpcHandler {
        target: "meeting"
        function start(minutes: int): string { meeting.start(minutes); return "on until " + Qt.formatTime(new Date(meeting.until), "HH:mm") }
        function stop(): string { meeting.stop(); return "off" }
        function status(): string { return JSON.stringify({active: meeting.active, until: meeting.until, inhibiting: inhibitor.running}) }
    }
}
