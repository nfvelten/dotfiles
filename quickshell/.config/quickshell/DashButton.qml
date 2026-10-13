import QtQuick
import QtQuick.Controls
Button {
    id: button
    required property QtObject theme
    property string hint: ""
    implicitHeight: 34
    implicitWidth: caption.implicitWidth + 26
    padding: 10
    contentItem: Text {
        id: caption
        text: button.text + (button.hint ? "   " + button.hint : "")
        color: button.theme.foreground
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 6
        color: Qt.alpha(button.theme.foreground, button.hovered || button.activeFocus ? 0.09 : 0.025)
        border.color: button.activeFocus ? button.theme.accent : Qt.alpha(button.theme.foreground, 0.12)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}
