import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The panel scaffolding here, meaning the open/close and IPC contract, is
// derived from Omarchy's `omarchy.weather` and `omarchy.agents` plugins
// (https://github.com/basecamp/omarchy, MIT, Copyright (c) David Heinemeier
// Hansson). See LICENSE for the full notice.

// Today's journal: what is on the agenda, what is still owed, what was noted.
//
// It renders whatever `bin/kbullet-today` hands it, and decides nothing itself.
// Where the journal lives, how a day file is laid out and what each symbol
// means are all decided in the collector, which runs from a terminal with no
// compositor involved. The panel's only job is to draw the day.
Panel {
  id: root
  moduleName: "brightwalker25.kbullet"
  ipcTarget: "brightwalker25.kbullet"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // The bar tracks the widget mounted in its slot, not this nested panel, so
  // the popout coordinator has to be handed that widget as the identity.
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Kbullet's own palette, fixed rather than drawn from the theme. These
  // colours are the entry's meaning rather than decoration, and an entry that
  // reads as one kind here and another in the app is worse than no colour.
  readonly property var symbolColors: ({
    "task":      "#3daee9",
    "event":     "#27ae60",
    "note":      "#f39c12",
    "mood":      "#e91e9b",
    "urgent":    "#ff5555",
    "priority":  "#ffaa00",
    "done":      "#7f8c8d",
    "migrated":  "#8e44ad",
    "scheduled": "#e74c3c",
    "delegated": "#16a085",
    "waiting":   "#9b59b6"
  })
  readonly property color badColor: "#f85149"

  function symbolColor(kind) {
    var c = root.symbolColors[String(kind)]
    return c !== undefined ? c : root.dim
  }

  readonly property int refreshMs: Math.max(5000, Number(setting("refreshIntervalMs", 30000)))
  readonly property int backgroundMs: Math.max(60000, Number(setting("backgroundIntervalMs", 300000)))
  readonly property bool hideDone: setting("hideDone", false) === true
  readonly property string journalOverride: String(setting("journalDir", ""))

  property var rep: null
  property string error: ""
  property bool loading: false

  // Read by the bar widget for its badge and urgent state.
  readonly property int openCount: rep && rep.openTasks !== undefined ? rep.openTasks : 0
  readonly property int urgentCount: rep && rep.urgent !== undefined ? rep.urgent : 0
  readonly property bool hasJournal: rep ? rep.exists === true : false
  readonly property bool syncing: rep ? rep.syncing === true : false
  readonly property string journalDir: rep && rep.journalDir ? String(rep.journalDir) : ""

  // Shipped inside the plugin and found relative to it, so there is no PATH
  // step to forget on the next machine.
  readonly property string collector: String(Qt.resolvedUrl("bin/kbullet-today")).replace(/^file:\/\//, "")

  readonly property bool dayEmpty: rep !== null && (!rep.entries || rep.entries.length === 0)

  readonly property var grouped: {
    var out = []
    if (!rep || !rep.sections || !rep.entries) return out
    for (var i = 0; i < rep.sections.length; i++) {
      var name = rep.sections[i]
      var items = []
      for (var j = 0; j < rep.entries.length; j++) {
        var e = rep.entries[j]
        if (e.section !== name) continue
        if (root.hideDone && e.done === true) continue
        items.push(e)
      }
      // The section is kept even when empty: the three-part shape of the day
      // is itself information.
      out.push({ section: name, items: items })
    }
    return out
  }

  function poll() {
    if (proc.running) return
    root.loading = true
    proc.running = true
  }

  function ingest(text) {
    var parsed = null
    try {
      parsed = JSON.parse(String(text))
    } catch (e) {
      root.error = "Could not parse collector output"
      return
    }
    if (!parsed || typeof parsed !== "object") return
    root.error = ""
    root.rep = parsed
  }

  Process {
    id: proc
    command: root.journalOverride !== ""
      ? [root.collector, "--journal-dir", root.journalOverride]
      : [root.collector]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.ingest(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = String(text || "").trim()
        if (t !== "") root.error = t
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && root.error === "")
        root.error = "Collector exited " + exitCode
    }
  }

  // Fast cadence while the panel is open.
  Timer {
    running: root.opened
    interval: root.refreshMs
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  // Slow backstop so the bar count stays honest with the panel closed, and so
  // the day rolls over at midnight even if nothing else fires.
  Timer {
    running: true
    interval: root.backgroundMs
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.rep && root.rep.date !== Qt.formatDate(new Date(), "yyyy-MM-dd"))
        root.rep = null
      root.poll()
    }
  }

  // The first read can race shell startup, so take one more shortly after.
  Timer {
    running: true
    interval: 1500
    repeat: false
    onTriggered: root.poll()
  }

  // Watches the folder rather than today's file: the file may not exist yet,
  // and a sync client writing temp-then-rename would break an inode watch.
  FileView {
    path: root.journalDir
    watchChanges: root.journalDir !== ""
    printErrors: false
    onFileChanged: settle.restart()
  }

  // Sync churn arrives in bursts; one read after it stops is enough.
  Timer {
    id: settle
    interval: 400
    repeat: false
    onTriggered: root.poll()
  }

  function fmtChecked() {
    if (!root.rep || !root.rep.generatedAt) return ""
    return "checked " + Qt.formatTime(new Date(root.rep.generatedAt * 1000), "HH:mm")
  }

  function fmtDate() {
    if (!root.rep || !root.rep.date) return ""
    return Qt.formatDate(Date.fromLocaleDateString(Qt.locale(), root.rep.date, "yyyy-MM-dd"),
                         "dddd d MMMM")
  }

  function summary() {
    if (root.syncing) return "syncing…"
    if (!root.hasJournal) return "nothing written yet"
    var s = root.openCount + " open"
    if (root.urgentCount > 0) s += " · " + root.urgentCount + " urgent"
    return s
  }

  // ------------------------------------------------------------------ actions

  // Uses the plugin's own focuser rather than omarchy-launch-or-focus, whose
  // pattern also matches window titles. A browser tab showing the repository,
  // or an editor holding kbullet.py, would be focused instead of the app.
  readonly property string focuser: String(Qt.resolvedUrl("bin/kbullet-focus")).replace(/^file:\/\//, "")

  function openKbullet() {
    Util.execArgv([root.focuser])
    root.close()
  }

  function quickCapture() {
    Util.execArgv(["quick-capture"])
    root.close()
  }

  // ------------------------------------------------------- open/close contract

  property bool openedFromHotkey: false

  function open() {
    openedFromHotkey = false
    root.controller.show()
    root.poll()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.poll()
  }

  function close() { root.controller.hide() }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      root.bar.switchPanelFrom(root.barIdentity, direction)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.poll() }
    function openApp(): void { root.openKbullet() }
    function capture(): void { root.quickCapture() }
  }

  // ------------------------------------------------------------- components

  // One entry: symbol in its own colour, then the time, then the text. The
  // symbol sits in a fixed gutter so the column reads straight down whatever
  // the glyph widths are.
  component EntryRow: Item {
    id: entryRow
    property var item: null
    readonly property bool isDone: item && item.done === true
    readonly property real gutter: Style.space(16)

    implicitHeight: Math.max(sym.implicitHeight, body.implicitHeight)

    Text {
      id: sym
      anchors.left: parent.left
      anchors.top: parent.top
      width: entryRow.gutter
      text: entryRow.item ? entryRow.item.symbol : ""
      color: entryRow.item ? root.symbolColor(entryRow.item.kind) : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      id: stamp
      anchors.left: sym.right
      anchors.top: parent.top
      visible: text !== ""
      text: entryRow.item && entryRow.item.time ? entryRow.item.time : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      id: body
      anchors.left: stamp.visible ? stamp.right : sym.right
      anchors.leftMargin: Style.spacing.sm
      anchors.right: parent.right
      anchors.top: parent.top
      // A truncated task is not a task, so it wraps and the row grows.
      wrapMode: Text.WordWrap
      text: entryRow.item ? entryRow.item.text : ""
      color: entryRow.isDone ? root.symbolColors["done"] : root.foreground
      opacity: entryRow.isDone ? 0.75 : 1.0
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.strikeout: entryRow.isDone
    }
  }

  component SectionHeading: Column {
    id: heading
    property string title: ""
    spacing: Style.spacing.sm
    PanelSeparator { width: heading.width; foreground: root.foreground }
    PanelSectionHeader {
      text: heading.title
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // ------------------------------------------------------------------ layout

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.spacing.lg

          // ---- Hero: the day, and what it still owes.
          Column {
            width: parent.width
            spacing: Style.spacing.xxs

            Text {
              width: parent.width
              text: root.fmtDate()
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.summary()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: root.fmtChecked()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              opacity: 0.7
            }
          }

          // ---- Nothing written yet: say so once, rather than drawing three
          // empty headings, and point at the fastest way to fix it.
          Column {
            width: parent.width
            spacing: Style.spacing.xs
            visible: root.dayEmpty && !root.syncing

            PanelSeparator { width: parent.width; foreground: root.foreground }

            Text {
              width: parent.width
              text: "Nothing written yet"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              width: parent.width
              text: "Use Quick capture below to add one"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              opacity: 0.8
            }
          }

          // ---- The day itself.
          Repeater {
            model: root.dayEmpty ? [] : root.grouped
            delegate: Column {
              required property var modelData
              width: column.width
              spacing: Style.spacing.sm

              SectionHeading {
                width: parent.width
                title: modelData.section
              }

              Text {
                width: parent.width
                visible: modelData.items.length === 0
                text: "nothing yet"
                color: root.dim
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: modelData.items
                delegate: EntryRow {
                  required property var modelData
                  width: parent.width
                  item: modelData
                }
              }
            }
          }

          // ---- Actions.
          Column {
            width: parent.width
            spacing: Style.spacing.sm

            PanelSeparator { width: parent.width; foreground: root.foreground }

            Row {
              width: parent.width
              spacing: Style.spacing.controlGap

              Button {
                width: (parent.width - Style.spacing.controlGap) / 2
                bordered: true
                focusable: true
                iconText: "󰠮"
                text: "Open Kbullet"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.openKbullet()
              }

              Button {
                width: (parent.width - Style.spacing.controlGap) / 2
                bordered: true
                focusable: true
                iconText: "󰐕"
                text: "Quick capture"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.quickCapture()
              }
            }
          }

          // Collector failures are shown rather than swallowed. A panel that
          // silently draws stale results is the failure mode worth avoiding.
          Column {
            width: parent.width
            spacing: Style.spacing.xs
            visible: root.error !== "" || (root.rep && root.rep.errors && root.rep.errors.length > 0)

            PanelSeparator { width: parent.width; foreground: root.foreground }

            Text {
              width: parent.width
              visible: root.error !== ""
              text: root.error
              color: root.badColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.rep && root.rep.errors ? root.rep.errors : []
              delegate: Text {
                required property var modelData
                width: column.width
                text: modelData
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }
    }
  }
}
