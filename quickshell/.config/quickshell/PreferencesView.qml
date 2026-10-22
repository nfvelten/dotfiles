import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FocusScope {
    id: view
    required property QtObject theme
    required property QtObject preferences
    signal back()
    signal closeRequested()
    signal helpRequested()
    signal themesRequested()
    property int selected: 0
    readonly property var generalItems: [
        {title: "Themes", subtitle: "Import Omarchy color palettes", key: "y", action: "themes"},
        {title: "Clickable buttons", subtitle: "Show mouse-friendly navigation controls", key: "b", value: preferences.showButtons},
        {title: "Top bar", subtitle: "Keep the workspace and status strip visible", key: "t", value: preferences.showTopBar},
        {title: "tmux morph", subtitle: "Animate the dock into the Super + C terminal", key: "m", value: preferences.tmuxMorph},
        {title: "Super key hints", subtitle: "Show the shortcut popup while holding Super", key: "h", value: preferences.showKeyHints},
        {title: "Off-work suggestions", subtitle: "Book, podcast and RSS card visibility", key: "i", value: preferences.idleSuggestionsMode}
    ]
    // Dashboard cards, in the user's order (Shift+J/K moves, c collapses, Enter shows/hides).
    readonly property var cardDefaults: [
        {title: "Agents card", subtitle: "Show active tmux agent work", name: "agents", key: "", preference: "showAgentsCard"},
        {title: "Gambito card", subtitle: "Show games waiting for your move", name: "gambito", key: "", preference: "showGambitoCard"},
        {title: "Notifications card", subtitle: "Show recent desktop notifications", name: "notifications", key: "", preference: "showNotificationsCard"},
        {title: "Calendar card", subtitle: "Show upcoming events", name: "calendar", key: "", preference: "showEventsCard"},
        {title: "Media card", subtitle: "Show what is playing (Spotify, browser…)", name: "media", key: "", preference: "showMediaCard"},
        {title: "Podcast card", subtitle: "Show the current Radiola player", name: "podcast", key: "", preference: "showPodcastCard"},
        {title: "Tasks card", subtitle: "Show open tasks from today's note", name: "tasks", key: "", preference: "showTasksCard"},
        {title: "Azure Boards card", subtitle: "Show your open Azure demands", name: "azure", key: "", preference: "showAzureCard"},
        {title: "Off-work card", subtitle: "Show books, podcasts and RSS suggestions", name: "idle", key: "", preference: "showIdleCard"}
    ]
    readonly property var cardOrder: {
        var saved = preferences.cardOrder ? preferences.cardOrder.split(",") : []
        var names = cardDefaults.map(function(c) { return c.name })
        return saved.filter(function(n) { return names.indexOf(n) >= 0 }).concat(names.filter(function(n) { return saved.indexOf(n) < 0 }))
    }
    readonly property var collapsedNames: preferences.collapsedCards ? preferences.collapsedCards.split(",") : []
    readonly property var cardRows: cardOrder.map(function(n) {
        var c = cardDefaults.find(function(d) { return d.name === n })
        return Object.assign({}, c, {value: preferences[c.preference], collapsed: collapsedNames.indexOf(n) >= 0})
    })
    readonly property var items: generalItems.concat(cardRows)
    function moveCard(index, delta) {
        var item = items[index], target = index + delta
        if (!item || !item.name || !items[target] || !items[target].name) return
        var order = cardOrder.slice(), i = order.indexOf(item.name)
        order.splice(i, 1); order.splice(i + delta, 0, item.name)
        preferences.cardOrder = order.join(","); preferences.sync()
        selected = target
    }
    function toggleCollapsed(index) {
        var item = items[index]
        if (!item || !item.name) return
        var names = collapsedNames.filter(function(n) { return n !== item.name })
        if (!item.collapsed) names.push(item.name)
        preferences.collapsedCards = names.join(","); preferences.sync()
    }
    function modeLabel(mode) {
        if (mode === "always") return "Always"
        if (mode === "never") return "Never"
        return "Outside work"
    }
    function toggle(index) {
        var item = items[index]
        if (item.action === "themes") { themesRequested(); return }
        if (item.preference) {
            preferences[item.preference] = !preferences[item.preference]
            preferences.sync()
            return
        }
        if (index === 1) preferences.showButtons = !preferences.showButtons
        else if (index === 2) preferences.showTopBar = !preferences.showTopBar
        else if (index === 3) preferences.tmuxMorph = !preferences.tmuxMorph
        else if (index === 4) preferences.showKeyHints = !preferences.showKeyHints
        else if (index === 5) {
            var modes = ["off-work", "always", "never"]
            preferences.idleSuggestionsMode = modes[(modes.indexOf(preferences.idleSuggestionsMode) + 1) % modes.length]
        }
        preferences.sync()
    }
    Keys.onPressed: function(event) {
        if (event.text === "?") helpRequested()
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) back()
        else if (event.key === Qt.Key_Down || event.text === "j") selected = Math.min(items.length - 1, selected + 1)
        else if (event.key === Qt.Key_Up || event.text === "k") selected = Math.max(0, selected - 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) toggle(selected)
        else if (event.text === "J") moveCard(selected, 1)
        else if (event.text === "K") moveCard(selected, -1)
        else if (event.text === "c") toggleCollapsed(selected)
        else if (event.text === "q") closeRequested()
        else return
        event.accepted = true
    }
    // Keep the selected row on screen; the card rows sit below the fold.
    onSelectedChanged: {
        var row = rowsRepeater.itemAt(selected), flick = scroller.contentItem
        if (!row || !flick) return
        var y = row.mapToItem(flick.contentItem, 0, 0).y
        if (y < flick.contentY) flick.contentY = Math.max(0, y - 8)
        else if (y + row.height > flick.contentY + flick.height) flick.contentY = y + row.height - flick.height + 8
    }
    ScrollView {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: view.width - 12
            spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Dock preferences"; color: theme.foreground; font.pixelSize: 20 }
            Item { Layout.fillWidth: true }
            Text { text: "Keyboard-first · Enter toggle"; color: theme.foreground; opacity: 0.55; font.pixelSize: 12 }
        }
        Text { text: "Appearance and interaction"; color: theme.foreground; opacity: 0.6; font.pixelSize: 12 }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                id: rowsRepeater
                model: view.items
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true; height: 58; radius: 7
                    color: index === view.selected ? Qt.alpha(theme.accent, 0.13) : Qt.alpha(theme.foreground, 0.035)
                    border.color: index === view.selected ? Qt.alpha(theme.accent, 0.4) : Qt.alpha(theme.foreground, 0.12)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: modelData.title; color: theme.foreground; font.pixelSize: 14 }
                            Text { text: (modelData.collapsed ? "Collapsed · " : "") + modelData.subtitle; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
                        }
                        Text { text: modelData.key; color: theme.foreground; opacity: 0.5; font.family: "monospace"; font.pixelSize: 11 }
                        Text {
                            text: modelData.action ? "Open" : (typeof modelData.value === "string" ? view.modeLabel(modelData.value) : (modelData.value ? "On" : "Off"))
                            color: modelData.action ? theme.accent : (modelData.value === "never" || modelData.value === false ? theme.foreground : theme.accent)
                            opacity: modelData.value === "never" || modelData.value === false ? 0.55 : 1
                            font.pixelSize: 13
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { view.selected = index; view.toggle(index) } }
                }
            }
        }
        Text { text: "Keyboard shortcuts"; color: theme.foreground; opacity: 0.6; font.pixelSize: 12 }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 28; rowSpacing: 5
            Text { text: "Super + Space"; color: theme.foreground; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "Open dock"; color: theme.foreground; opacity: 0.6; font.pixelSize: 11 }
            Text { text: "s"; color: theme.foreground; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "Dock preferences"; color: theme.foreground; opacity: 0.6; font.pixelSize: 11 }
            Text { text: "b"; color: theme.foreground; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "Toggle clickable buttons"; color: theme.foreground; opacity: 0.6; font.pixelSize: 11 }
            Text { text: "?"; color: theme.foreground; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "Show contextual help"; color: theme.foreground; opacity: 0.6; font.pixelSize: 11 }
        }
        Item { Layout.fillHeight: true }
            Text { text: "↑ ↓ / j k select · Enter toggle · Shift+J/K move card · c collapse card · Esc back"; color: theme.foreground; opacity: 0.55; font.pixelSize: 11 }
        }
    }
}
