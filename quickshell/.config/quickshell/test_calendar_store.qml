import QtQuick
import Quickshell
ShellRoot {
    id:test
    property int opened:0
    CalendarStore {
        id:store; automatic:false
        settingsPath:"file://"+Quickshell.env("CALENDAR_TEST_SETTINGS")
        onEventRequested:function(item) { test.opened++ }
    }
    Component.onCompleted: {
        if (!Quickshell.env("CALENDAR_TEST_SETTINGS") || !Quickshell.env("CALENDAR_TEST_LOG")) { console.error("Set isolated test settings and mock notify-send first"); Qt.quit(); return }
        var date=new Date(Date.now()+15*60000)
        var sample={calendar:"test",uid:"test",title:"Calendar synthetic",date:Qt.formatDate(date,"yyyy-MM-dd"),time:Qt.formatTime(date,"HH:mm"),endDate:Qt.formatDate(date,"yyyy-MM-dd"),endTime:Qt.formatTime(new Date(date.getTime()+3600000),"HH:mm")}
        store.setKeywords("Calendar synthetic")
        store.setMinutes(15)
        store.agenda=[sample]; store.fetchedAt=Date.now()
        store.tick();store.tick()
    }
    Timer {
        running:true;interval:1500
        onTriggered:{console.log("CALENDAR_TEST",JSON.stringify({opened:test.opened,config:store.config}));Qt.quit()}
    }
}
