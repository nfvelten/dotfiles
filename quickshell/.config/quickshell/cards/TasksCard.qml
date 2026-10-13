import QtQuick
import QtQuick.Layouts

// Open checkboxes in today's daily note.
Card {
    id: card
    active: feed.preferences.showTasksCard && feed.org.home.taskCount > 0
    priority: 40
    title: "Today · " + feed.org.home.taskCount + " open"
    key: "d"
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "d note · n capture"
            Repeater {
                model: card.feed.org.home.tasks.slice(0, 3)
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text: "□  " + modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight
                    color: card.theme.foreground; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; onClicked: card.feed.org.run("open", [modelData.orgPath, String(modelData.orgLine)]) }
                }
            }
        }
    }
}
