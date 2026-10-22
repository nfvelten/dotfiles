import QtQuick
QtObject {
    readonly property color background: "#$background"
    readonly property color surface: "#$muted"
    readonly property color surfaceHover: "#$accent"
    readonly property color foreground: "#$foreground"
    readonly property color muted: "#$foreground"
    readonly property color border: "#$accent"
    readonly property color accent: "#$accent"
    readonly property color error: "#$red"
    readonly property int radius: 12
    readonly property string font: "$font"
    readonly property var ansi: ["#$black", "#$red", "#$green", "#$yellow", "#$blue", "#$magenta", "#$cyan", "#$white", "#$bright_black", "#$bright_red", "#$bright_green", "#$bright_yellow", "#$bright_blue", "#$bright_magenta", "#$bright_cyan", "#$bright_white"]
}
