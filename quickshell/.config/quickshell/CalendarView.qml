import QtQuick
import QtQuick.Layouts

// Calendar page (key C): month grid plus the selected day's events, fed by khal.
FocusScope {
    id: view
    required property QtObject theme
    required property QtObject org
    signal back()
    signal helpRequested()
    signal closeRequested()
    property date selectedDate: new Date()
    property int eventIndex: -1
    readonly property string dateKey: Qt.formatDate(selectedDate, "yyyy-MM-dd")
    readonly property var dayEvents: org.events.filter(function(e) { return e.date === dateKey })
    readonly property var event: eventIndex >= 0 ? dayEvents[eventIndex] || null : null
    function changeDay(delta) { var d = new Date(selectedDate); d.setDate(d.getDate() + delta); selectedDate = d }
    function changeMonth(delta) { selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + delta, 1) }
    onSelectedDateChanged: { org.month = Qt.formatDate(selectedDate, "yyyy-MM"); eventIndex = -1 }
    // Leave the store on the current month so the "Coming up" card keeps working.
    Component.onDestruction: org.month = Qt.formatDate(new Date(), "yyyy-MM")
    Keys.onPressed: function(event) {
        var k = event.text
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { if (eventIndex >= 0) eventIndex = -1; else back() }
        else if (k === "?") helpRequested()
        else if (k === "q") closeRequested()
        else if (k === "h" || event.key === Qt.Key_Left) changeDay(-1)
        else if (k === "l" || event.key === Qt.Key_Right) changeDay(1)
        else if (k === "k" || event.key === Qt.Key_Up) changeDay(-7)
        else if (k === "j" || event.key === Qt.Key_Down) changeDay(7)
        else if (k === "[" || event.key === Qt.Key_PageUp) changeMonth(-1)
        else if (k === "]" || event.key === Qt.Key_PageDown) changeMonth(1)
        else if (k === "g") selectedDate = new Date()
        else if (k === "J") eventIndex = Math.min(dayEvents.length - 1, eventIndex + 1)
        else if (k === "K") eventIndex = Math.max(-1, eventIndex - 1)
        else return
        event.accepted = true
    }
    RowLayout {
        anchors.fill: parent; spacing: 16
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Qt.alpha(theme.foreground, 0.035); border.color: Qt.alpha(theme.foreground, 0.12); radius: 10
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 10
                RowLayout {
                    Text { Layout.fillWidth: true; text: view.selectedDate.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy"); color: theme.foreground; font.pixelSize: 16 }
                    Text { text: "[  ]  month · g today"; color: theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                }
                // The month grid takes all the room it has: 7 columns, a weekday row and 6 week rows.
                Item {
                    id: cells
                    Layout.fillWidth: true; Layout.fillHeight: true
                    readonly property real cellWidth: width / 7
                    readonly property real cellHeight: (height - 30) / 6
                    Grid {
                        columns: 7
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text { required property string modelData; width: cells.cellWidth; height: 30; text: modelData; horizontalAlignment: Text.AlignHCenter; color: theme.foreground; opacity: 0.5; font.pixelSize: 12 }
                        }
                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: day
                                required property int index
                                readonly property date date: new Date(view.selectedDate.getFullYear(), view.selectedDate.getMonth(), 1 + index - (new Date(view.selectedDate.getFullYear(), view.selectedDate.getMonth(), 1).getDay() + 6) % 7)
                                readonly property string key: Qt.formatDate(date, "yyyy-MM-dd")
                                readonly property bool chosen: key === view.dateKey
                                width: cells.cellWidth - 4; height: cells.cellHeight - 4; radius: 8
                                color: chosen ? Qt.alpha(theme.accent, 0.22) : "transparent"
                                border.color: chosen ? theme.accent : "transparent"
                                Text { anchors.centerIn: parent; text: day.date.getDate(); color: theme.foreground; opacity: day.date.getMonth() === view.selectedDate.getMonth() ? 1 : 0.3; font.pixelSize: Math.max(13, Math.min(18, cells.cellHeight * 0.32)); font.bold: day.key === Qt.formatDate(new Date(), "yyyy-MM-dd") }
                                Rectangle { width: 5; height: 5; radius: 3; color: theme.accent; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; visible: view.org.events.some(function(e) { return e.date === day.key }) }
                                MouseArea { anchors.fill: parent; onClicked: { view.selectedDate = day.date; view.forceActiveFocus() } }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.preferredWidth: 380; Layout.fillHeight: true
            color: Qt.alpha(theme.foreground, 0.035); border.color: Qt.alpha(theme.foreground, 0.12); radius: 10
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 10
                RowLayout {
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: view.selectedDate.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d") + " · " + view.dayEvents.length + " events"; color: theme.foreground; font.pixelSize: 16 }
                    Text { text: "J K select"; color: theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: view.dayEvents
                    currentIndex: view.eventIndex
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: view.eventIndex === index
                        width: ListView.view.width; height: column.implicitHeight + 16; radius: 6
                        color: selected ? Qt.alpha(theme.accent, 0.13) : "transparent"
                        border.color: selected ? Qt.alpha(theme.accent, 0.4) : "transparent"
                        Column {
                            id: column
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 10
                            spacing: 4
                            Text { width: parent.width; text: (row.modelData.time || "All day") + "  " + row.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.foreground; font.pixelSize: 13 }
                            Text { text: row.modelData.calendar + (row.modelData.location ? " · " + row.modelData.location : ""); color: theme.foreground; opacity: 0.5; font.pixelSize: 11 }
                            Text { visible: row.selected && !!row.modelData.description; width: parent.width; text: row.modelData.description || ""; textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight; color: theme.foreground; opacity: 0.8; font.pixelSize: 12 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { view.eventIndex = row.index; view.forceActiveFocus() } }
                    }
                    Text { visible: !view.dayEvents.length; text: view.org.calendarLoading ? "Loading agenda…" : view.org.calendarError || "No events this day"; color: theme.foreground; opacity: 0.6; font.pixelSize: 12 }
                }
            }
        }
    }
}
