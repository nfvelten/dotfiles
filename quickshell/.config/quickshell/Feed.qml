import QtQuick
import Quickshell
import "cards"

// The "Now" feed: card providers stay alive (event-driven, cheap); the dashboard only
// instantiates views for active cards while the dock is open. Add a card = add a file + a line here.
Scope {
    id: feed
    required property QtObject theme
    required property QtObject org
    required property QtObject notifications
    required property QtObject media
    required property QtObject preferences
    property bool open: false
    readonly property QtObject tmux: org.tmux
    signal navigate(string route)
    signal openTmux(var item)
    signal closeRequested()

    AgentsCard { id: agents; theme: feed.theme; feed: feed }
    GambitoCard { id: gambito; theme: feed.theme; feed: feed }
    NotificationsCard { id: notices; theme: feed.theme; feed: feed }
    EventCard { id: event; theme: feed.theme; feed: feed }
    MediaCard { id: mediaCard; theme: feed.theme; feed: feed; media: feed.media }
    PodcastCard { id: podcastCard; theme: feed.theme; feed: feed; podcast: feed.podcast }
    TasksCard { id: tasks; theme: feed.theme; feed: feed }
    AzureCard { id: azureCard; theme: feed.theme; feed: feed }
    IdleCard { id: idle; theme: feed.theme; feed: feed }

    readonly property var all: [agents, gambito, notices, event, mediaCard, podcastCard, tasks, azureCard, idle]
    AzureStore { id: azureStore; active: feed.open }
    readonly property QtObject azure: azureStore
    PodcastStore { id: podcastStore; active: feed.open }
    readonly property QtObject podcast: podcastStore
    readonly property var cards: all.filter(function(c) { return c.active }).sort(function(a, b) { return b.priority - a.priority })
    // "Nothing happening": no card that wants attention (today's tasks and a paused player don't count).
    readonly property bool quiet: !all.some(function(c) { return c !== idle && c.active && c.priority >= 50 })
    function handleKey(text, key) {
        for (var i = 0; i < cards.length; i++) if (cards[i].handleKey(text, key)) return true
        return false
    }
}
