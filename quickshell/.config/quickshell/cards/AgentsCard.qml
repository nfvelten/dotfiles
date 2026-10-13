import QtQuick
import QtQuick.Layouts

// Agents that are working or waiting on you; idle agents stay behind `t`.
Card {
    id: card
    readonly property var busy: feed.tmux.agents.filter(function(a) { return a.status !== "idle" })
        .sort(function(a, b) { return (b.status === "waiting") - (a.status === "waiting") })
    readonly property bool waiting: busy.some(function(a) { return a.status === "waiting" })
    active: feed.preferences.showAgentsCard && busy.length > 0
    priority: waiting ? 100 : 50
    title: waiting ? "An agent needs you" : "Agents working"
    key: "a1–3"
    function handleKey(text, key) {
        var n = text.length === 2 && text[0].toLowerCase() === "a" ? Number(text[1]) : 0
        if (n >= 1 && n <= 3 && busy[n - 1]) { feed.openTmux(busy[n - 1]); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "a1–3 · t all"; urgent: card.waiting
            Repeater {
                model: card.busy.slice(0, 3)
                delegate: Item {
                    id: agentRow
                    required property var modelData
                    required property int index
                    readonly property bool working: modelData.status === "working"
                    Layout.fillWidth: true; implicitHeight: 40
                    Column {
                        anchors.fill: parent; spacing: 4
                        RowLayout {
                            width: parent.width; spacing: 7
                            Text { text: agentRow.index + 1; color: card.theme.foreground; opacity: 0.45; font.family: "monospace"; font.pixelSize: 11 }
                            Text {
                                text: agentRow.working ? "●" : "◐"; color: card.theme.accent; font.pixelSize: 11
                                SequentialAnimation on opacity {
                                    running: agentRow.working; loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            Text { Layout.fillWidth: true; text: agentRow.modelData.title.replace(/^\S\s+/, ""); color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                            Text { text: agentRow.working ? "working" : "needs you"; color: agentRow.working ? card.theme.foreground : card.theme.accent; opacity: agentRow.working ? 0.55 : 1; font.pixelSize: 10 }
                        }
                        Text { width: parent.width; leftPadding: 30; text: agentRow.modelData.sessionName + " · " + (agentRow.modelData.line || agentRow.modelData.agent); color: card.theme.foreground; opacity: 0.6; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                    }
                    MouseArea { anchors.fill: parent; onClicked: card.feed.openTmux(agentRow.modelData) }
                }
            }
        }
    }
}
