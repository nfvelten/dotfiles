import QtQuick
import QtQuick.Layouts

Card {
    id: card
    readonly property var openItems: feed.azure.items
    active: feed.preferences.showAzureCard && openItems.length > 0
    priority: 45
    title: "Azure · " + openItems.length + " open"
    key: "A"
    function handleKey(text, key) {
        if (text === "A" && openItems.length) { card.feed.navigate("boards"); return true }
        return false
    }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "A open"
            TapHandler { onTapped: card.feed.navigate("boards") }
            Repeater {
                model: card.openItems.slice(0, 3)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "#" + modelData.id; color: card.theme.accent; font.family: "monospace"; font.pixelSize: 11 }
                    Text { Layout.fillWidth: true; text: modelData.title; color: card.theme.foreground; font.pixelSize: 12; elide: Text.ElideRight; textFormat: Text.PlainText }
                    Text { text: modelData.state; color: card.theme.foreground; opacity: 0.55; font.pixelSize: 10 }
                    TapHandler { onTapped: card.feed.navigate("boards") }
                }
            }
        }
    }
}
