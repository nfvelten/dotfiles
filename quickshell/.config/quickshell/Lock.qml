import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    property alias locked: sessionLock.locked
    property string password: ""
    property bool authenticating: false
    property string statusText: ""
    signal unlocked()

    function authenticate() {
        if (authenticating || password.length === 0)
            return
        authenticating = true
        statusText = ""
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: "/etc/pam.d"
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired)
                respond(root.password)
        }

        onCompleted: result => {
            root.authenticating = false
            if (result === PamResult.Success) {
                root.password = ""
                sessionLock.locked = false
                root.unlocked()
            } else {
                root.password = ""
                root.statusText = "Incorrect password"
            }
        }

        onError: {
            root.authenticating = false
            root.password = ""
            root.statusText = "Authentication failed"
        }
    }

    WlSessionLock {
        id: sessionLock

        Connections {
            target: sessionLock
            function onSecureChanged() {
                if (sessionLock.secure && sessionLock.locked)
                    blankTimer.restart()
            }
            function onLockStateChanged() {
                if (sessionLock.locked) {
                    blankTimer.restart()
                } else {
                    blankTimer.stop()
                    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"enable\" })"])
                }
            }
        }

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: root
            }
        }
    }

    Timer {
        id: blankTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (sessionLock.locked)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"disable\" })"])
        }
    }
}
