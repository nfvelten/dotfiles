import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import "CalendarLogic.js" as Logic

FocusScope {
    id: view
    required property QtObject theme
    required property QtObject org
    readonly property var calendar: org.calendar
    signal back()
    signal helpRequested()
    signal closeRequested()
    property date selectedDate: new Date()
    property string mode: "month"
    property bool favoritesOnly: false
    property bool settingsOpen: false
    property bool detailOpen: false
    property int eventIndex: -1
    readonly property string dateKey: Logic.dateKey(selectedDate)
    readonly property var dayEvents: {
        var data = mode === "week" ? calendar.agenda : calendar.events
        var start = mode === "week" ? calendar.today : dateKey
        var last = new Date(); last.setDate(last.getDate()+7)
        var end = mode === "week" ? Logic.dateKey(last) : dateKey
        return data.filter(function(e) {
            return e.date >= start && (mode === "week" ? e.date < end : e.date === end)
                && (!favoritesOnly || calendar.favorite(e))
        }).sort(function(a,b) { return (a.date + a.time).localeCompare(b.date + b.time) })
    }
    readonly property var event: eventIndex >= 0 ? dayEvents[eventIndex] || null : null
    onDayEventsChanged: { if (eventIndex >= dayEvents.length) eventIndex = dayEvents.length-1 }
    function changeDay(delta) { var d = new Date(selectedDate); d.setDate(d.getDate()+delta); selectedDate=d; mode="month" }
    function changeMonth(delta) { selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth()+delta, 1); mode="month" }
    // Enter or a click on a day moves focus into its event list, where j/k, f and n act on events.
    function openDay() { if (dayEvents.length) eventIndex=0 }
    function selectToday() { selectedDate = new Date(); mode="month"; eventIndex=-1 }
    function selectEvent(item) {
        selectedDate = new Date(Number(item.date.slice(0,4)), Number(item.date.slice(5,7))-1, Number(item.date.slice(8,10)))
        mode="month"; favoritesOnly=false
        calendar.openEvent = item
        findPending()
    }
    function findPending() {
        if (!calendar.openEvent) return
        var id = calendar.key(calendar.openEvent)
        for (var i=0; i<dayEvents.length; i++) if (calendar.key(dayEvents[i]) === id) {
            eventIndex=i; detailOpen=true; calendar.openEvent=null; return
        }
    }
    onSelectedDateChanged: { calendar.month = Logic.dateKey(selectedDate).slice(0,7); eventIndex=-1; detailOpen=false }
    Component.onCompleted: { calendar.browsing=true; if (calendar.openEvent) selectEvent(calendar.openEvent) }
    Component.onDestruction: { calendar.browsing=false; calendar.month=Logic.dateKey(new Date()).slice(0,7) }
    Connections {
        target: view.calendar
        function onEventsChanged() { view.findPending() }
        function onOpenEventChanged() { if (view.calendar.openEvent) view.selectEvent(view.calendar.openEvent) }
    }
    Keys.onPressed: function(keyEvent) {
        var k=keyEvent.text
        if (keyEvent.key === Qt.Key_Escape || keyEvent.key === Qt.Key_Backspace) {
            if (detailOpen) detailOpen=false
            else if (settingsOpen) settingsOpen=false
            else if (eventIndex>=0) eventIndex=-1
            else back()
        } else if (k === "?") helpRequested()
        else if (k === "q") closeRequested()
        else if (k === "n" && event) calendar.cycleReminder(event)
        else if (k === "f" && event) calendar.toggleFavorite(event)
        else if (k === "r") calendar.synchronize()
        else if (k === "g") selectToday()
        else if (k === "w") { mode=mode==="week"?"month":"week"; eventIndex=-1 }
        else if (k === "F") favoritesOnly=!favoritesOnly
        else if (k === "s") settingsOpen=!settingsOpen
        else if (keyEvent.key === Qt.Key_Return || keyEvent.key === Qt.Key_Enter) { if (event) detailOpen=true; else openDay() }
        else if (k === "J" || ((mode !== "month" || eventIndex >= 0) && (k === "j" || keyEvent.key === Qt.Key_Down))) eventIndex=Math.min(dayEvents.length-1,eventIndex+1)
        else if (k === "K" || ((mode !== "month" || eventIndex >= 0) && (k === "k" || keyEvent.key === Qt.Key_Up))) eventIndex=Math.max(eventIndex>=0?0:-1,eventIndex-1)
        else if (k === "h" || keyEvent.key === Qt.Key_Left) changeDay(-1)
        else if (k === "l" || keyEvent.key === Qt.Key_Right) changeDay(1)
        else if (k === "k" || keyEvent.key === Qt.Key_Up) changeDay(-7)
        else if (k === "j" || keyEvent.key === Qt.Key_Down) changeDay(7)
        else if (k === "[" || keyEvent.key === Qt.Key_PageUp) changeMonth(-1)
        else if (k === "]" || keyEvent.key === Qt.Key_PageDown) changeMonth(1)
        else return
        keyEvent.accepted=true
    }
    ColumnLayout {
        anchors.fill: parent; spacing: 8
        Rectangle {
            visible:view.settingsOpen; Layout.fillWidth:true; implicitHeight:settingsColumn.implicitHeight+16
            color:Qt.alpha(view.theme.foreground,0.035); radius:8
            ColumnLayout {
                id:settingsColumn; anchors.left:parent.left; anchors.right:parent.right; anchors.top:parent.top; anchors.margins:8; spacing:6
                RowLayout {
                    Layout.fillWidth:true
                    DashButton { theme:view.theme; text:view.calendar.config.enabled?"Reminders on":"Reminders off"; onClicked:view.calendar.toggleEnabled() }
                    DashButton { theme:view.theme; text:view.calendar.config.minutes+" min before"; onClicked:view.calendar.cycleMinutes() }
                    Item { Layout.fillWidth:true }
                }
                Text {
                    Layout.fillWidth:true; color:view.theme.foreground; opacity:0.6; font.pixelSize:11; wrapMode:Text.Wrap
                    text:"Reminds only starred (f) or marked (n) events."
                }
                Text { Layout.fillWidth:true; text:view.calendar.syncSummary+" · r syncs"; color:view.theme.foreground; opacity:0.6; font.pixelSize:11; elide:Text.ElideRight }
            }
        }
        Text { visible:!!(view.calendar.error||view.calendar.agendaError); Layout.fillWidth:true; text:view.calendar.error||view.calendar.agendaError; color:view.theme.accent; font.pixelSize:11; wrapMode:Text.Wrap }
        RowLayout {
            Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
            Rectangle {
                visible:view.mode==="month"; Layout.preferredWidth:Math.min(390,view.width*0.43); Layout.fillHeight:true
                color:Qt.alpha(view.theme.foreground,0.035); border.color:Qt.alpha(view.theme.foreground,0.12); radius:10
                ColumnLayout {
                    anchors.fill:parent; anchors.margins:12; spacing:8
                    RowLayout {
                        DashButton { theme:view.theme; text:"‹"; onClicked:view.changeMonth(-1) }
                        Text { Layout.fillWidth:true; horizontalAlignment:Text.AlignHCenter; text:view.selectedDate.toLocaleDateString(Qt.locale("en_US"),"MMMM yyyy"); color:view.theme.foreground; font.pixelSize:15 }
                        DashButton { theme:view.theme; text:"›"; onClicked:view.changeMonth(1) }
                    }
                    Item {
                        id:cells; Layout.fillWidth:true; Layout.fillHeight:true
                        readonly property real cellWidth:width/7
                        readonly property real cellHeight:Math.max(20,(height-24)/6)
                        Grid {
                            columns:7
                            Repeater { model:["S","M","T","W","T","F","S"]; Text { required property string modelData; width:cells.cellWidth; height:24; text:modelData; horizontalAlignment:Text.AlignHCenter; color:view.theme.foreground; opacity:0.5; font.pixelSize:11 } }
                            Repeater {
                                model:42
                                Rectangle {
                                    id:day; required property int index
                                    readonly property date date:new Date(view.selectedDate.getFullYear(),view.selectedDate.getMonth(),1+index-new Date(view.selectedDate.getFullYear(),view.selectedDate.getMonth(),1).getDay())
                                    readonly property string key:Logic.dateKey(date)
                                    width:cells.cellWidth; height:cells.cellHeight; radius:6
                                    color:key===view.dateKey?Qt.alpha(view.theme.accent,0.22):"transparent"
                                    Text { anchors.centerIn:parent; text:day.date.getDate(); color:view.theme.foreground; opacity:day.date.getMonth()===view.selectedDate.getMonth()?1:0.3; font.bold:day.key===view.calendar.today; font.pixelSize:14 }
                                    Rectangle { width:4;height:4;radius:2;color:view.theme.accent;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:3;visible:view.calendar.events.some(function(e){return e.date===day.key}) }
                                    MouseArea { anchors.fill:parent; onClicked:{view.selectedDate=day.date;view.openDay();view.forceActiveFocus()} }
                                }
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth:true; Layout.fillHeight:true; spacing:6
                Text { text:(view.mode==="week"?"Next seven days":view.selectedDate.toLocaleDateString(Qt.locale("en_US"),"dddd, MMMM d"))+" · "+view.dayEvents.length+(view.dayEvents.length===1?" event":" events"); color:view.theme.foreground; font.pixelSize:15 }
                ListView {
                    id:eventsList; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:5
                    model:view.dayEvents; currentIndex:view.eventIndex
                    highlightRangeMode:ListView.ApplyRange
                    ScrollBar.vertical:ScrollBar {}
                    delegate:Rectangle {
                        id:row; required property var modelData; required property int index
                        width:ListView.view.width; height:70; radius:7
                        color:index===view.eventIndex?Qt.alpha(view.theme.accent,0.13):Qt.alpha(view.theme.foreground,0.025)
                        border.color:index===view.eventIndex?Qt.alpha(view.theme.accent,0.4):"transparent"
                        Column {
                            anchors.left:parent.left; anchors.right:countdown.left; anchors.verticalCenter:parent.verticalCenter; anchors.margins:10; spacing:5
                            Text { width:parent.width; text:(view.calendar.favorite(row.modelData)?"★ ":"")+(view.mode==="week"?row.modelData.date.slice(8,10)+"/"+row.modelData.date.slice(5,7)+" · ":"")+(row.modelData.time||"All day")+"  "+row.modelData.title; color:view.theme.foreground; font.pixelSize:13; textFormat:Text.PlainText; elide:Text.ElideRight }
                            Text { width:parent.width; text:view.calendar.labelFor(row.modelData.calendar)+(view.calendar.cancelled(row.modelData)?" · postponed/cancelled":"")+(row.modelData.location?" · "+row.modelData.location:""); textFormat:Text.PlainText; color:view.theme.foreground; opacity:0.6; font.pixelSize:11; elide:Text.ElideRight }
                        }
                        Text { id:countdown; anchors.right:parent.right; anchors.rightMargin:12; anchors.verticalCenter:parent.verticalCenter; text:view.calendar.countdown(row.modelData); color:view.theme.accent; font.pixelSize:12 }
                        MouseArea { anchors.fill:parent; onClicked:{view.eventIndex=row.index;view.forceActiveFocus()} onDoubleClicked:{view.eventIndex=row.index;view.detailOpen=true} }
                    }
                    Text { anchors.centerIn:parent; visible:!view.dayEvents.length; text:view.calendar.loading?"Loading calendar…":(view.favoritesOnly?"No starred events this day":"No events this day"); color:view.theme.foreground; opacity:0.6; font.pixelSize:13 }
                }
            }
        }
    }
    Rectangle {
        anchors.fill:parent; visible:view.detailOpen&&!!view.event; color:view.theme.background; radius:10; border.color:Qt.alpha(view.theme.foreground,0.15)
        ColumnLayout {
            anchors.fill:parent; anchors.margins:18; spacing:12
            RowLayout {
                Text { Layout.fillWidth:true; text:view.event?view.event.title:""; textFormat:Text.PlainText; color:view.theme.foreground; font.pixelSize:19; wrapMode:Text.Wrap }
                DashButton { theme:view.theme; text:"Back"; onClicked:{view.detailOpen=false;view.forceActiveFocus()} }
            }
            Text { text:view.event?view.event.date+" · "+(view.event.time||"All day")+(view.event.endTime?" → "+view.event.endTime:"")+" · "+view.calendar.labelFor(view.event.calendar):""; color:view.theme.accent; font.pixelSize:13 }
            Text { visible:!!view.event&&!!view.event.location; text:view.event?view.event.location:""; textFormat:Text.PlainText; color:view.theme.foreground; font.pixelSize:12; wrapMode:Text.Wrap; Layout.fillWidth:true }
            ScrollView {
                Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                Text { width:parent.width; text:view.event?(view.event.description||"No description in the source."):""; textFormat:Text.PlainText; color:view.theme.foreground; font.pixelSize:14; wrapMode:Text.Wrap }
            }
            RowLayout {
                DashButton { theme:view.theme; text:view.event?view.calendar.reminderLabel(view.event):""; enabled:!!view.event&&!!view.event.time&&!view.calendar.cancelled(view.event); onClicked:view.calendar.cycleReminder(view.event) }
                DashButton { theme:view.theme; text:view.event&&view.calendar.favorite(view.event)?"★ Favorito":"☆ Favoritar"; onClicked:view.calendar.toggleFavorite(view.event) }
                DashButton { theme:view.theme; visible:!!view.event&&!!view.calendar.eventUrl(view.event); text:"Open link"; onClicked:Quickshell.execDetached(["uwsm","app","--","xdg-open",view.calendar.eventUrl(view.event)]) }
                Item { Layout.fillWidth:true }
            }
        }
    }
}
