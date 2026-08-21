import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "harbefas.system-stats"
  ipcTarget: "harbefas.system-stats"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property color fill: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property real cpuPercent: 0
  property real memoryPercent: 0
  property real swapPercent: 0
  property real diskPercent: 0
  property string memoryText: "--"
  property string swapText: "--"
  property string diskText: "--"
  property string loadText: "--"
  property string uptimeText: "--"
  property var processes: []
  property var cores: []
  property double previousCpuTotal: 0
  property double previousCpuIdle: 0
  property var previousCoreTotals: ({})
  property var previousCoreIdles: ({})

  function clamp(value) { return Math.max(0, Math.min(1, Number(value) || 0)) }
  function formatBytes(value) {
    var n = Number(value) || 0
    var units = ["B", "K", "M", "G", "T"]
    var index = 0
    while (n >= 1024 && index < units.length - 1) { n /= 1024; index++ }
    return (n >= 10 || index === 0 ? Math.round(n) : n.toFixed(1)) + units[index]
  }
  function formatRate(value) { return formatBytes(value) + "/s" }
  function formatUptime(seconds) {
    var s = Math.max(0, Number(seconds) || 0)
    var days = Math.floor(s / 86400)
    var hours = Math.floor((s % 86400) / 3600)
    var minutes = Math.floor((s % 3600) / 60)
    var secs = Math.floor(s % 60)
    var hms = String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    return "up " + (days > 0 ? days + "d " : "") + hms
  }
  function updateLine(line, newProcesses, newCores) {
    var parts = String(line).trim().split("|")
    if (parts.length < 2) return
    if (parts[0] === "cpu" && parts.length >= 3) {
      var total = Number(parts[1]); var idle = Number(parts[2])
      var totalDelta = total - previousCpuTotal; var idleDelta = idle - previousCpuIdle
      if (previousCpuTotal > 0 && totalDelta > 0) cpuPercent = clamp((totalDelta - idleDelta) / totalDelta)
      previousCpuTotal = total; previousCpuIdle = idle
    } else if (parts[0] === "memory" && parts.length >= 3) {
      var mt = Number(parts[1]) * 1024; var ma = Number(parts[2]) * 1024; var mu = mt - ma
      memoryPercent = clamp(mu / mt); memoryText = formatBytes(mu) + " / " + formatBytes(mt)
    } else if (parts[0] === "swap" && parts.length >= 3) {
      var st = Number(parts[1]); var sf = Number(parts[2]); var su = st - sf
      swapPercent = st > 0 ? clamp(su / st) : 0; swapText = st > 0 ? formatBytes(su) + " / " + formatBytes(st) : "Not used"
    } else if (parts[0] === "disk" && parts.length >= 4) {
      diskPercent = clamp(Number(parts[3]) / 100); diskText = formatBytes(parts[1]) + " / " + formatBytes(parts[2])
    } else if (parts[0] === "load" && parts.length >= 4) {
      loadText = parts[1] + "  " + parts[2] + "  " + parts[3]
    } else if (parts[0] === "uptime" && parts.length >= 2) {
      uptimeText = formatUptime(parts[1])
    } else if (parts[0] === "core" && parts.length >= 5) {
      var idx = parts[1]
      var cTotal = Number(parts[2]); var cIdle = Number(parts[3]); var cTemp = Number(parts[4])
      var cPrevTotal = previousCoreTotals[idx] || 0; var cPrevIdle = previousCoreIdles[idx] || 0
      var cTotalDelta = cTotal - cPrevTotal; var cIdleDelta = cIdle - cPrevIdle
      var cPercent = (cPrevTotal > 0 && cTotalDelta > 0) ? clamp((cTotalDelta - cIdleDelta) / cTotalDelta) : 0
      previousCoreTotals[idx] = cTotal; previousCoreIdles[idx] = cIdle
      newCores.push({ index: Number(idx), percent: cPercent, temp: cTemp })
    } else if (parts[0] === "process" && parts.length >= 4) {
      newProcesses.push({ name: parts[1], cpu: Number(parts[2]), memory: Number(parts[3]) })
    }
  }
  function applyStats(output) {
    var lines = String(output).split("\n")
    var newProcesses = []
    var newCores = []
    for (var i = 0; i < lines.length; i++) updateLine(lines[i], newProcesses, newCores)
    processes = newProcesses
    cores = newCores
  }
  function refresh() {
    statsProc.running = true
  }
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  Timer { interval: 2500; running: root.opened; repeat: true; onTriggered: root.refresh() }

  Process {
    id: statsProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/harbefas.system-stats/bin/stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStats(text) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    active: root.opened
    onPressed: root.toggle()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) refresh()

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Keep the popup stable while the process list is refreshed asynchronously.
    contentHeight: panel.fittedContentHeight(Style.space(720), Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }
    }

    Column {
      id: column
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(14)
        Text { text: "󰍛"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.display }
        Column {
          spacing: Style.space(2)
          Text { text: "System stats"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
          Text { text: "LIVE HARDWARE OVERVIEW"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1.2 }
        }
      }

      PanelSeparator { foreground: root.foreground }
      PanelSectionHeader { text: "SYSTEM LOAD"; foreground: root.foreground; fontFamily: root.fontFamily }
      MetricRow { label: "CPU"; value: Math.round(root.cpuPercent * 100) + "%"; ratio: root.cpuPercent; foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily }
      MetricRow { label: "MEMORY"; value: root.memoryText; ratio: root.memoryPercent; foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily }
      MetricRow { label: "SWAP"; value: root.swapText; ratio: root.swapPercent; foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily }
      MetricRow { label: "DISK /"; value: root.diskText; ratio: root.diskPercent; foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily }
      Text { width: parent.width; text: "Load " + root.loadText + "   " + root.uptimeText; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignRight }

      PanelSeparator { foreground: root.foreground }
      PanelSectionHeader { text: "CPU CORES"; foreground: root.foreground; fontFamily: root.fontFamily }
      Row {
        width: parent.width
        spacing: Style.space(12)
        Column {
          width: (parent.width - Style.space(12)) / 2
          spacing: Style.space(2)
          Repeater {
            model: root.cores.slice(0, Math.ceil(root.cores.length / 2))
            delegate: CoreRow {
              required property var modelData
              index: modelData.index; percent: modelData.percent; temp: modelData.temp
              foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily
            }
          }
        }
        Column {
          width: (parent.width - Style.space(12)) / 2
          spacing: Style.space(2)
          Repeater {
            model: root.cores.slice(Math.ceil(root.cores.length / 2))
            delegate: CoreRow {
              required property var modelData
              index: modelData.index; percent: modelData.percent; temp: modelData.temp
              foreground: root.foreground; dim: root.dim; track: root.track; fill: root.fill; fontFamily: root.fontFamily
            }
          }
        }
      }

      PanelSeparator { foreground: root.foreground }
      PanelSectionHeader { text: "TOP PROCESSES"; foreground: root.foreground; fontFamily: root.fontFamily }
      Item {
        width: parent.width
        height: Style.space(160)

        Column {
          anchors.fill: parent
          spacing: 0

          Repeater {
            model: root.processes
            delegate: Row {
              required property var modelData
              width: column.width
              height: Style.space(30)
              spacing: Style.space(8)
              Text { width: parent.width - 100; text: modelData.name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
              Text { width: 42; text: Number(modelData.cpu).toFixed(1) + "%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignRight }
              Text { width: 42; text: Number(modelData.memory).toFixed(1) + "%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignRight }
            }
          }
        }
      }
    }
  }

  component MetricRow: Item {
    property string label
    property string value
    property real ratio
    property color foreground
    property color dim
    property color track
    property color fill
    property string fontFamily
    width: parent.width
    implicitHeight: Style.space(32)
    Text { id: metricLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: parent.foreground; font.family: parent.fontFamily; font.pixelSize: Style.font.body }
    Text { id: metricValue; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: parent.value; color: parent.foreground; font.family: parent.fontFamily; font.pixelSize: Style.font.body; horizontalAlignment: Text.AlignRight }
    Rectangle { anchors.left: metricLabel.right; anchors.right: metricValue.left; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; height: Style.space(6); radius: height / 2; color: parent.track }
    Rectangle { anchors.left: metricLabel.right; anchors.leftMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; width: Math.max(Style.space(3), (parent.width - metricLabel.width - metricValue.width - Style.space(24)) * parent.ratio); height: Style.space(6); radius: height / 2; color: parent.fill }
  }

  component CoreRow: Item {
    property int index
    property real percent
    property real temp
    property color foreground
    property color dim
    property color track
    property color fill
    property string fontFamily
    width: parent.width
    implicitHeight: Style.space(20)
    Text { id: coreLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Style.space(20); text: "C" + parent.index; color: parent.dim; font.family: parent.fontFamily; font.pixelSize: Style.font.bodySmall }
    Text { id: coreTemp; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: Style.space(32); horizontalAlignment: Text.AlignRight; text: parent.temp >= 0 ? parent.temp + "°C" : ""; color: parent.dim; font.family: parent.fontFamily; font.pixelSize: Style.font.bodySmall }
    Text { id: corePct; anchors.right: coreTemp.left; anchors.rightMargin: Style.space(4); anchors.verticalCenter: parent.verticalCenter; width: Style.space(26); horizontalAlignment: Text.AlignRight; text: Math.round(parent.percent * 100) + "%"; color: parent.dim; font.family: parent.fontFamily; font.pixelSize: Style.font.bodySmall }
    Rectangle { id: coreTrack; anchors.left: coreLabel.right; anchors.leftMargin: Style.space(4); anchors.right: corePct.left; anchors.rightMargin: Style.space(4); anchors.verticalCenter: parent.verticalCenter; height: Style.space(5); radius: height / 2; color: parent.track }
    Rectangle { anchors.left: coreLabel.right; anchors.leftMargin: Style.space(4); anchors.verticalCenter: parent.verticalCenter; width: Math.max(Style.space(2), coreTrack.width * parent.percent); height: Style.space(5); radius: height / 2; color: parent.fill }
  }
}
