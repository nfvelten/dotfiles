import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Online games where it's your move, pushed by the Gambito daemon (`gambito watch` NDJSON).
Card {
    id: card
    property var games: []
    active: feed.preferences.showGambitoCard && games.length > 0
    priority: 95
    title: games.length > 1 ? games.length + " games · your move" : "Your move"
    key: "g"
    function clock(ms) { var s = Math.max(0, Math.round(ms / 1000)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
    function open(game) { Quickshell.execDetached(["gambito", "open", game.id]); feed.closeRequested() }
    function handleKey(text, key) {
        if (text === "g" && games.length) { open(games[0]); return true }
        return false
    }
    Process {
        id: watcher
        command: ["gambito", "watch", "--json"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var state = JSON.parse(line)
                    if (state.type !== "state") return
                    card.games = (state.games || []).filter(function(g) {
                        return g.status === "started" && g.turn === g.color && !g.analysis && !g.puzzle
                    }).map(function(g) {
                        var mine = g.color === "white"
                        return {id: g.id, opponent: mine ? g.black : g.white, rating: mine ? g.black_rating : g.white_rating,
                                ms: mine ? g.white_ms : g.black_ms, last: (g.san || []).slice(-1)[0] || "", speed: g.speed}
                    })
                } catch (e) {}
            }
        }
        // Daemon not running or restarted: try again later instead of spinning.
        onExited: { card.games = []; retry.start() }
    }
    Timer { id: retry; interval: 60000; onTriggered: watcher.running = true }
    view: Component {
        CardFrame {
            theme: card.theme; title: card.title; hint: "g open"; urgent: true
            Repeater {
                model: card.games.slice(0, 2)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 10
                    Text { text: "♟"; color: card.theme.accent; font.pixelSize: 15 }
                    Text { Layout.fillWidth: true; text: "vs " + modelData.opponent + " (" + modelData.rating + ")" + (modelData.last ? " · played " + modelData.last : ""); color: card.theme.foreground; font.pixelSize: 13; textFormat: Text.PlainText; elide: Text.ElideRight }
                    Text { text: modelData.speed === "correspondence" ? "" : card.clock(modelData.ms); color: card.theme.foreground; opacity: 0.7; font.family: "monospace"; font.pixelSize: 12 }
                    TapHandler { onTapped: card.open(modelData) }
                }
            }
        }
    }
}
