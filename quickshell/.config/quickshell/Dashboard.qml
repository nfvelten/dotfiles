import QtQuick
import QtQuick.Layouts

// "Now" dashboard: only cards with something to show, ordered by urgency. Pages
// (agents, notes, calendar, clipboard, apps, controls) open from the bottom row.
FocusScope {
    id: dashboard
    required property QtObject theme
    required property QtObject org
    required property QtObject feed
    required property QtObject buttonPreferences
    signal navigate(string route)
    signal openTmux(var item)
    signal searchRequested()
    signal closeRequested()
    signal helpRequested()
    readonly property var cards: feed.cards
    readonly property var collapsedNames: buttonPreferences.collapsedCards ? buttonPreferences.collapsedCards.split(",") : []
    function isCollapsed(name) { return collapsedNames.indexOf(name) >= 0 }
    function toggleCollapsed(name) {
        var names = collapsedNames.filter(function(n) { return n !== name })
        if (!isCollapsed(name)) names.push(name)
        buttonPreferences.collapsedCards = names.join(",")
        buttonPreferences.sync()
    }
    readonly property bool showButtons: buttonPreferences.showButtons
    implicitHeight: layout.implicitHeight
    // Keyboard first, Gambito style: contextual card keys, then global dashboard keys.
    Keys.onPressed: function(event) {
        var k = event.text
        // Cards get first refusal. This keeps contextual actions such as `l` (open the
        // suggested book) from being swallowed by a global dashboard shortcut.
        if (feed.handleKey(k, event.key)) { event.accepted = true; return }
        if (k === "/" || k === "i") searchRequested()
        else if (k === "b") { buttonPreferences.showButtons = !buttonPreferences.showButtons; buttonPreferences.sync() }
        else if (k === "?") helpRequested()
        else if (k === "q" || event.key === Qt.Key_Escape) closeRequested()
        else if (k === "n") navigate("capture")
        else if (k === "d") org.run("today")
        else if (k === "o") navigate("notes")
        else if (k === "t") navigate("tmux")
        else if (k === "C") navigate("calendar")
        else if (k === "m") navigate("media")
        else if (k === "c") navigate("audio")
        else if (k === "w") navigate("network")
        else if (k === "B") navigate("bluetooth")
        else if (k === "v") navigate("clipboard")
        else if (k === "a") navigate("applications")
        else if (k === "P") navigate("power")
        else if (k === "s") navigate("preferences")
        else return
        event.accepted = true
    }
    ColumnLayout {
        id: layout
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: dashboard.showButtons
            DashButton { theme: dashboard.theme; text: "+  Capture task"; hint: "n"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("capture") }
            DashButton { theme: dashboard.theme; text: "↗  Today's note"; hint: "d"; focusPolicy: Qt.NoFocus; onClicked: org.run("today") }
            DashButton { theme: dashboard.theme; text: "Settings"; hint: "s"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("preferences") }
            Item { Layout.fillWidth: true }
            Text { text: new Date().toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d"); color: theme.foreground; opacity: 0.6; font.pixelSize: 12 }
        }
        Text {
            visible: !dashboard.cards.length && !feed.org.loading && !feed.org.error
            Layout.fillWidth: true; Layout.topMargin: 18; Layout.bottomMargin: 18
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing needs you right now"
            color: theme.foreground; opacity: 0.5; font.pixelSize: 14
        }
        Text {
            visible: !dashboard.cards.length && feed.org.loading
            Layout.fillWidth: true; Layout.topMargin: 18; Layout.bottomMargin: 18
            horizontalAlignment: Text.AlignHCenter
            text: "Updating dashboard…"
            color: theme.foreground; opacity: 0.55; font.pixelSize: 14
        }
        Text {
            visible: !dashboard.cards.length && !!feed.org.error
            Layout.fillWidth: true; Layout.topMargin: 18; Layout.bottomMargin: 18
            horizontalAlignment: Text.AlignHCenter
            text: feed.org.error
            color: theme.accent; opacity: 0.85; font.pixelSize: 13
        }
        RowLayout {
            visible: dashboard.cards.length > 0
            Layout.fillWidth: true
            spacing: 14
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 14
                Repeater {
                    model: dashboard.cards.filter(function(card, index) { return index % 2 === 0 })
                    delegate: Loader {
                        id: cardLoader
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        sourceComponent: modelData.view
                        Binding { when: !!cardLoader.item; target: cardLoader.item; property: "collapsed"; value: dashboard.isCollapsed(cardLoader.modelData.name) }
                        Connections { target: cardLoader.item; ignoreUnknownSignals: true; function onCollapseToggled() { dashboard.toggleCollapsed(cardLoader.modelData.name) } }
                    }
                }
            }
            ColumnLayout {
                visible: dashboard.cards.length > 1
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 14
                Repeater {
                    model: dashboard.cards.filter(function(card, index) { return index % 2 === 1 })
                    delegate: Loader {
                        id: cardLoader
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        sourceComponent: modelData.view
                        Binding { when: !!cardLoader.item; target: cardLoader.item; property: "collapsed"; value: dashboard.isCollapsed(cardLoader.modelData.name) }
                        Connections { target: cardLoader.item; ignoreUnknownSignals: true; function onCollapseToggled() { dashboard.toggleCollapsed(cardLoader.modelData.name) } }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: dashboard.showButtons
            Text { text: "/ search · ? keys · b buttons"; color: theme.foreground; opacity: 0.5; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            DashButton { theme: dashboard.theme; text: "Agents"; hint: "t"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("tmux") }
            DashButton { theme: dashboard.theme; text: "Notes"; hint: "o"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("notes") }
            DashButton { theme: dashboard.theme; text: "Calendar"; hint: "C"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("calendar") }
            DashButton { theme: dashboard.theme; text: "Media"; hint: "m"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("media") }
            DashButton { theme: dashboard.theme; text: "Clipboard"; hint: "v"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("clipboard") }
            DashButton { theme: dashboard.theme; text: "Apps"; hint: "a"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("applications") }
            DashButton { theme: dashboard.theme; text: "Audio"; hint: "c"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("audio") }
            DashButton { theme: dashboard.theme; text: "Bluetooth"; hint: "B"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("bluetooth") }
            DashButton { theme: dashboard.theme; text: "Network"; hint: "w"; focusPolicy: Qt.NoFocus; onClicked: dashboard.navigate("network") }
        }
    }
}
