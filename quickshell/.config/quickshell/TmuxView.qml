import QtQuick
import QtQuick.Layouts

Item {
    id: view
    required property QtObject theme
    required property QtObject store
    required property var rows
    required property int selected
    required property bool showButtons
    signal select(int index)
    signal activate(int index)
    readonly property var current: rows[selected] || null
    ColumnLayout {
        anchors.fill: parent; spacing: 14
        RowLayout {
            ColumnLayout {
                Layout.fillWidth: true; spacing: 3
                Text { text: "Your terminal · tmux"; color: theme.foreground; font.pixelSize: 20 }
                Text { text: store.sessions.length + " sessions · " + rows.length + " windows · " + store.agents.length + " agents"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Text { text: "Enter / e resume · Super + C"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
            ListView {
                id: windows
                Layout.preferredWidth: 270; Layout.fillHeight: true
                clip: true; model: view.rows; currentIndex: view.selected
                onCurrentIndexChanged: { if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain) }
                section.property: "sessionName"
                section.delegate: Text {
                    required property string section
                    width: windows.width; height: 32
                    text: section; color: theme.foreground; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: windows.width; height: 82; radius: 7
                    color: view.selected === index ? Qt.alpha(theme.accent, 0.14) : Qt.alpha(theme.foreground, 0.018)
                    border.width: view.selected === index ? 1 : 0
                    border.color: Qt.alpha(theme.accent, 0.45)
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Row {
                            width: parent.width; spacing: 7
                            Text {
                                readonly property bool agent: !!modelData.agent
                                readonly property bool working: modelData.status === "working"
                                readonly property bool waiting: modelData.status === "waiting"
                                visible: agent
                                text: working || waiting ? "●" : "○"
                                color: working ? theme.accent : waiting ? "#cc241d" : theme.foreground
                                opacity: working || waiting ? 1 : 0.55
                                font.pixelSize: 11
                            }
                            Text { width: parent.width - 20; text: modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 13 }
                        }
                        Text { width: parent.width; text: modelData.sessionName + " · " + (modelData.agent || modelData.paneCommand || "shell"); color: theme.foreground; opacity: 0.62; font.pixelSize: 11; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.panePath || modelData.line || (modelData.active ? "Active window" : "Available window"); color: theme.foreground; opacity: 0.42; font.pixelSize: 10; elide: Text.ElideMiddle }
                    }
                    MouseArea { anchors.fill: parent; onClicked: view.select(index); onDoubleClicked: view.activate(index) }
                }
                Text { visible: !view.rows.length; width: parent.width; wrapMode: Text.Wrap; text: store.loading ? "Loading sessions…" : store.error || "No windows found"; color: theme.foreground; opacity: 0.6; font.pixelSize: 12 }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: Qt.alpha(theme.foreground, 0.035); border.color: Qt.alpha(theme.foreground, 0.12); radius: 9
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout {
                        Text { Layout.fillWidth: true; text: view.current ? view.current.title : "Terminal preview"; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 14 }
                        Text {
                            text: store.previewError ? "● paused" : view.current ? "● live" : "○ idle"; color: store.previewError ? theme.foreground : theme.accent; font.pixelSize: 10
                            SequentialAnimation on opacity {
                                running: !store.previewError && !!view.current; loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
                    Item {
                        id: terminal
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        FontMetrics { id: cell; font.family: theme.font; font.pixelSize: 100 }
                        // Ajusta a fonte para caber as colunas reais do pane; ancora no fim como no terminal.
                        readonly property int fontSize: Math.max(7, Math.min(13, Math.floor(Math.min(width / (store.previewCols * cell.advanceWidth("M") / 100), height / (store.previewRows * cell.height / 100)))))
                        Text {
                            id: terminalText
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            text: store.previewError ? "<pre>" + store.previewError + "</pre>" : store.previewHtml || (view.current ? "<pre>Loading preview…</pre>" : "<pre>Select a window</pre>")
                            textFormat: Text.RichText
                            font.family: theme.font; font.pixelSize: terminal.fontSize
                            color: theme.foreground
                        }
                    }
                    Text { Layout.fillWidth: true; text: view.current ? (view.current.subtitle + "   ·   Enter/e resume") : "Select a window to inspect its live pane"; textFormat: Text.PlainText; elide: Text.ElideMiddle; color: theme.foreground; opacity: 0.55; font.pixelSize: 10 }
                }
            }
        }
    }
}
