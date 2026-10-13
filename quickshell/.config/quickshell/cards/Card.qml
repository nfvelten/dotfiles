import QtQuick
import Quickshell

// Card contract: a headless provider that stays alive (cheap, event-driven) and a view
// the dashboard instantiates only while the dock is open and the card is active.
Scope {
    property QtObject theme
    // The Feed: exposes navigate(route), openTmux(item) and the shared stores.
    property QtObject feed
    property bool active: false
    property int priority: 0
    property string title: ""
    property string key: ""
    property Component view
    // Return true when the key was handled. `text` is event.text, `key` is event.key.
    function handleKey(text, key) { return false }
}
