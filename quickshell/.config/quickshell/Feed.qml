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
    property bool boardsOpen: false
    readonly property QtObject tmux: org.tmux
    signal navigate(string route)
    signal openTmux(var item)
    signal closeRequested()

    AgentsCard { id: agents; name: "agents"; theme: feed.theme; feed: feed }
    GambitoCard { id: gambito; name: "gambito"; theme: feed.theme; feed: feed }
    NotificationsCard { id: notices; name: "notifications"; theme: feed.theme; feed: feed }
    EventCard { id: event; name: "calendar"; theme: feed.theme; feed: feed }
    MediaCard { id: mediaCard; name: "media"; theme: feed.theme; feed: feed; media: feed.media }
    PodcastCard { id: podcastCard; name: "podcast"; theme: feed.theme; feed: feed; podcast: feed.podcast }
    TasksCard { id: tasks; name: "tasks"; theme: feed.theme; feed: feed }
    AzureCard { id: azureCard; name: "azure"; theme: feed.theme; feed: feed }
    IdleCard { id: idle; name: "idle"; theme: feed.theme; feed: feed }

    readonly property var all: [agents, gambito, notices, event, mediaCard, podcastCard, tasks, azureCard, idle]
    // Fetch only when something shows it: the card (if enabled) or the Boards page.
    AzureStore { id: azureStore; active: feed.open && (feed.preferences.showAzureCard || feed.boardsOpen) }
    readonly property QtObject azure: azureStore
    property QtObject yerbad: null
    PodcastStore { id: podcastStore; yerbad: feed.yerbad; active: feed.open }
    readonly property QtObject podcast: podcastStore
    // Urgent cards (priority >= 90: an agent or game waiting on you, a critical notification) always
    // lead; the rest follow the user's order from Preferences, or urgency when none is set.
    readonly property var order: preferences.cardOrder ? preferences.cardOrder.split(",") : []
    function rank(c) {
        if (c.priority >= 90 || !order.length) return -c.priority
        var i = order.indexOf(c.name)
        return i < 0 ? 1000 - c.priority : i
    }
    readonly property var cards: all.filter(function(c) { return c.active }).sort(function(a, b) {
        var urgentA = a.priority >= 90, urgentB = b.priority >= 90
        if (urgentA !== urgentB) return urgentA ? -1 : 1
        return rank(a) - rank(b)
    })
    // "Nothing happening": no card that wants attention (today's tasks and a paused player don't count).
    readonly property bool quiet: !all.some(function(c) { return c !== idle && c.active && c.priority >= 50 })
    function handleKey(text, key) {
        for (var i = 0; i < cards.length; i++) if (cards[i].handleKey(text, key)) return true
        return false
    }
}
