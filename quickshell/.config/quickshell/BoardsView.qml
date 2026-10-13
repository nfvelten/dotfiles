import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FocusScope {
    id: view
    required property QtObject theme
    required property QtObject store
    required property QtObject buttonPreferences
    signal back()
    signal closeRequested()
    signal helpRequested()
    property int selected: 0
    property bool detailMode: false
    readonly property bool showButtons: buttonPreferences.showButtons

    function openItem(item) {
        if (item && item.url) Qt.openUrlExternally(item.url)
    }
    function showDetail(item) {
        if (!item) return
        detailMode = true
        store.loadDetail(item.id)
    }
    function leaveDetail() { detailMode = false; store.detail = null; forceActiveFocus() }
    function refresh() { store.refresh() }

    Keys.onPressed: function(event) {
        if (event.text === "?") helpRequested()
        else if (event.text === "b") { buttonPreferences.showButtons = !buttonPreferences.showButtons; buttonPreferences.sync() }
        else if (event.text === "r") refresh()
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { if (detailMode) leaveDetail(); else back() }
        else if (event.key === Qt.Key_Q) closeRequested()
        else if (event.key === Qt.Key_Down) selected = Math.min(Math.max(0, store.items.length - 1), selected + 1)
        else if (event.key === Qt.Key_Up) selected = Math.max(0, selected - 1)
        else if (detailMode && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.text === "o")) openItem(store.items[selected])
        else if (!detailMode && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.text === "o")) showDetail(store.items[selected])
        else return
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        RowLayout {
            visible: !view.detailMode
            Layout.fillWidth: true
            Text { text: "Azure Boards"; color: theme.foreground; font.pixelSize: 20 }
            Item { Layout.fillWidth: true }
            Text { text: store.loading ? "Updating…" : store.items.length + " open"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
        }
        RowLayout {
            visible: view.showButtons
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Demandas atribuídas a você"; color: theme.foreground; opacity: 0.65; font.pixelSize: 12 }
            DashButton { theme: view.theme; text: "Refresh"; hint: "r"; focusPolicy: Qt.NoFocus; onClicked: view.refresh() }
        }
        Rectangle {
            visible: !view.detailMode
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: 8; color: Qt.alpha(theme.foreground, 0.025); border.color: Qt.alpha(theme.foreground, 0.1)
            ListView {
                id: list
                anchors.fill: parent; anchors.margins: 6; clip: true
                model: store.items
                currentIndex: view.selected
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: ListView.view.width; height: 58; radius: 6
                    color: index === view.selected ? Qt.alpha(theme.accent, 0.13) : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        Text { text: "#" + modelData.id; color: theme.accent; font.family: "monospace"; font.pixelSize: 11 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { Layout.fillWidth: true; text: modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 13 }
                            Text { Layout.fillWidth: true; text: modelData.subtitle || modelData.assigned; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
                        }
                        Text { text: modelData.state; color: theme.foreground; opacity: 0.6; font.pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { view.selected = index; view.showDetail(modelData) } }
                }
            }
            Column {
                anchors.centerIn: parent; spacing: 8
                visible: !store.loading && !store.items.length
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: store.error || "Nenhuma demanda aberta"; color: store.error ? theme.accent : theme.foreground; font.pixelSize: 14 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: store.error ? "Pressione r para tentar novamente" : "As demandas aparecerão aqui quando existirem"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
            }
        }
        Rectangle {
            visible: view.detailMode
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: 8; color: Qt.alpha(theme.foreground, 0.025); border.color: Qt.alpha(theme.foreground, 0.1)
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 18; spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "#" + (store.detail ? store.detail.id : store.items[selected].id); color: theme.accent; font.family: "monospace"; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: store.detail ? store.detail.title : store.items[selected].title; color: theme.foreground; font.pixelSize: 18; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Rectangle {
                        visible: !!store.detail && !!store.detail.state
                        implicitWidth: stateLabel.implicitWidth + 18; implicitHeight: 26; radius: 13
                        color: Qt.alpha(theme.accent, 0.14); border.color: Qt.alpha(theme.accent, 0.45)
                        Text { id: stateLabel; anchors.centerIn: parent; text: store.detail ? store.detail.state : ""; color: theme.accent; font.pixelSize: 11 }
                    }
                    DashButton { visible: view.showButtons; theme: view.theme; text: "Abrir no Azure"; hint: "o"; focusPolicy: Qt.NoFocus; onClicked: view.openItem(store.items[selected]) }
                }
                Text { visible: store.detailLoading; text: "Carregando detalhes…"; color: theme.foreground; opacity: 0.6; font.pixelSize: 13 }
                Text { visible: !!store.detail && !!store.detail.error; text: store.detail && store.detail.error ? String(store.detail.error) : ""; color: theme.accent; font.pixelSize: 13 }
                GridLayout {
                    visible: !!store.detail && !store.detail.error
                    columns: 2; columnSpacing: 16; rowSpacing: 8
                    Text { text: "Estado"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                    Text { text: store.detail ? store.detail.state : ""; color: theme.foreground; font.pixelSize: 12 }
                    Text { text: "Tipo"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                    Text { text: store.detail ? store.detail.type : ""; color: theme.foreground; font.pixelSize: 12 }
                    Text { text: "Responsável"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                    Text { text: store.detail ? store.detail.assigned : ""; color: theme.foreground; font.pixelSize: 12 }
                    Text { text: "Sprint"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: store.detail ? store.detail.iteration : ""; color: theme.foreground; font.pixelSize: 12; elide: Text.ElideRight }
                }
                Text {
                    visible: !!store.detail && (!!store.detail.tags || !!store.detail.priority)
                    Layout.fillWidth: true
                    text: (store.detail.tags ? "Tags: " + store.detail.tags : "") + (store.detail.priority ? "   Prioridade: " + store.detail.priority : "")
                    color: theme.foreground; opacity: 0.6; textFormat: Text.PlainText; font.pixelSize: 11
                }
                ScrollView {
                    visible: !!store.detail && !store.detail.error
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: 12
                        Text { text: "Descrição"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                        Text { Layout.fillWidth: true; text: store.detail ? (store.detail.description || "Sem descrição") : ""; color: theme.foreground; wrapMode: Text.Wrap; textFormat: Text.PlainText; font.pixelSize: 13 }
                        Rectangle { visible: !!store.detail && !!store.detail.acceptance; Layout.fillWidth: true; implicitHeight: acceptanceColumn.implicitHeight + 18; radius: 6; color: Qt.alpha(theme.accent, 0.06); border.color: Qt.alpha(theme.accent, 0.22)
                            ColumnLayout { id: acceptanceColumn; anchors.fill: parent; anchors.margins: 10; spacing: 4
                                Text { text: "Critérios de aceite"; color: theme.accent; font.pixelSize: 11 }
                                Text { Layout.fillWidth: true; text: store.detail ? store.detail.acceptance : ""; color: theme.foreground; opacity: 0.8; wrapMode: Text.Wrap; textFormat: Text.PlainText; font.pixelSize: 12 }
                            }
                        }
                        Text { visible: store.detail && store.detail.comments && store.detail.comments.length > 0; text: "Comentários · " + store.detail.comments.length; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
                        Repeater {
                            model: store.detail && store.detail.comments ? store.detail.comments : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; implicitHeight: commentColumn.implicitHeight + 18
                                radius: 6; color: Qt.alpha(theme.foreground, 0.035); border.color: Qt.alpha(theme.foreground, 0.1)
                                ColumnLayout {
                                    id: commentColumn
                                    anchors.fill: parent; anchors.margins: 9; spacing: 4
                                    Text { Layout.fillWidth: true; text: modelData.author + " · " + modelData.date; color: theme.accent; opacity: 0.8; font.pixelSize: 11 }
                                    Text { Layout.fillWidth: true; text: modelData.text; color: theme.foreground; wrapMode: Text.Wrap; textFormat: Text.PlainText; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                }
                Text { text: "Esc / Backspace voltar para a lista · o abrir no Azure"; color: theme.foreground; opacity: 0.5; font.pixelSize: 11 }
            }
        }
    }
    Component.onCompleted: forceActiveFocus()
}
