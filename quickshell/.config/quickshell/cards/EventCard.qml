import QtQuick
import QtQuick.Layouts

Card {
    id:card
    readonly property var calendar:feed.org.calendar
    readonly property var soon:calendar.upcoming
    active:feed.preferences.showEventsCard&&soon.length>0
    priority:70
    title:"Coming up"
    key:"C"
    view:Component {
        CardFrame {
            theme:card.theme; title:card.title; hint:"C calendar"
            TapHandler { onTapped:card.feed.navigate("calendar") }
            Repeater {
                model:card.soon.slice(0,3)
                delegate:RowLayout {
                    required property var modelData
                    Layout.fillWidth:true; spacing:10
                    Text { text:card.calendar.countdown(modelData); color:card.theme.accent; font.pixelSize:12 }
                    Text { Layout.fillWidth:true; text:(card.calendar.favorite(modelData)?"★ ":"")+(card.calendar.startOf(modelData)<=card.calendar.now?"started "+modelData.time+" · ":modelData.time+"  ")+modelData.title; color:card.theme.foreground; font.pixelSize:13; textFormat:Text.PlainText; elide:Text.ElideRight }
                }
            }
            Text { visible:card.soon.length>3; text:"+ "+(card.soon.length-3)+" more · open calendar"; color:card.theme.accent; font.pixelSize:11 }
        }
    }
}
