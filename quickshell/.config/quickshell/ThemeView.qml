import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FocusScope {
    id: view
    required property QtObject theme
    signal back()
    signal closeRequested()
    property var themes: []
    property int selected: 0
    property string message: "Loading themes…"
    property string importUrl: ""
    readonly property string bridge: Quickshell.env("HOME") + "/.config/quickshell/yerba_theme_bridge.py"

    Process {
        id: loader
        command: ["python3", view.bridge, "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { view.themes = JSON.parse(text); view.message = view.themes.length ? "" : "No local themes found" }
                catch (e) { view.message = "Could not read themes" }
            }
        }
    }
    Process {
        id: importer
        property string url: ""
        command: ["python3", view.bridge, "import", url]
        onExited: {
            view.importUrl = ""
            view.message = importer.exitCode === 0 ? "Theme imported" : "Import failed"
            loader.running = true
        }
    }
    Process {
        id: apply
        property string path: ""
        command: ["bash", "-lc", "python3 \"$1\" apply \"$2\" && systemctl --user restart quickshell.service", "theme", view.bridge, path]
        onExited: { view.message = "Theme applied" }
    }
    function choose(index) {
        selected = index
        var item = themes[index]
        if (!item || apply.running) return
        apply.path = item.path
        view.message = "Applying " + item.name + "…"
        apply.running = true
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { back(); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.text === "j") { selected = Math.min(themes.length - 1, selected + 1); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.text === "k") { selected = Math.max(0, selected - 1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { choose(selected); event.accepted = true }
        else if (event.text === "q") closeRequested()
    }
    ColumnLayout {
        anchors.fill: parent; spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Themes"; color: theme.foreground; font.pixelSize: 20 }
            Item { Layout.fillWidth: true }
            Text { text: "Omarchy palettes · local"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
        }
        Text { Layout.fillWidth: true; text: "Paletas encontradas em ~/.local/share/yerba/themes, ~/.config/omarchy/themes e no sistema."; color: theme.foreground; opacity: 0.65; wrapMode: Text.WordWrap; font.pixelSize: 12 }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
            color: Qt.alpha(theme.foreground, 0.025); border.color: Qt.alpha(theme.foreground, 0.1)
            ListView {
                id: list; anchors.fill: parent; anchors.margins: 6; clip: true
                model: view.themes
                delegate: Rectangle {
                    required property int index; required property var modelData
                    width: list.width; height: 96; radius: 9
                    color: index === view.selected ? Qt.alpha(theme.accent, 0.16) : "transparent"
                    border.width: index === view.selected ? 1 : 0
                    border.color: Qt.alpha(theme.accent, 0.55)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: modelData.name; color: theme.foreground; font.pixelSize: 15 }
                            Row {
                                spacing: 5
                                Repeater {
                                    model: modelData.colors || []
                                    delegate: Rectangle { width: 34; height: 24; radius: 5; color: "#" + modelData; border.color: Qt.alpha(theme.foreground, 0.18) }
                                }
                            }
                            Text { text: modelData.preview ? "Omarchy theme · preview available" : "Omarchy-compatible palette"; color: theme.foreground; opacity: 0.5; font.pixelSize: 11 }
                        }
                        Text { text: index === view.selected ? "Selected" : "Enter apply"; color: index === view.selected ? theme.accent : theme.foreground; opacity: index === view.selected ? 1 : 0.5; font.pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: view.choose(index) }
                }
            }
            Text { anchors.centerIn: parent; visible: !view.themes.length; text: view.message; color: theme.foreground; opacity: 0.6 }
        }
        Text { text: view.message; visible: view.message.length > 0 && view.themes.length > 0; color: theme.accent; font.pixelSize: 12 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            TextInput {
                id: urlInput
                Layout.fillWidth: true; height: 34
                color: theme.foreground; font.pixelSize: 12
                clip: true
                text: view.importUrl
                onTextChanged: view.importUrl = text
                Text { visible: !parent.text; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "URL do repositório Omarchy (GitHub)"; color: theme.foreground; opacity: 0.45 }
                Rectangle { anchors.fill: parent; anchors.margins: -8; z: -1; radius: 6; color: Qt.alpha(theme.foreground, 0.04); border.color: theme.border }
            }
            DashButton { theme: view.theme; text: "Import"; hint: ""; onClicked: if (view.importUrl.trim() && !importer.running) { importer.url = view.importUrl.trim(); view.message = "Importing…"; importer.running = true } }
        }
        Text { text: "↑ ↓ / j k selecionar · Enter aplicar · Esc voltar"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
    }
}
