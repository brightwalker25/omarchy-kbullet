import QtQuick
import qs.Commons
import qs.Ui

// Derived from Omarchy's own `omarchy.weather` bar widget
// (https://github.com/basecamp/omarchy, MIT, Copyright (c) David Heinemeier
// Hansson). The injectPanel / open / close / closeForPopoutSwitch contract
// below is what the bar requires of any widget hosting a panel, and this file
// follows that implementation closely. See LICENSE for the full notice.

// The glyph, plus the number of things still owed today.
//
// Unlike a network check, this count is cheap and local, being a read of one
// small file, so it is honest to show it continuously and to keep it current
// while the panel is closed. The count is what makes the widget worth a bar
// slot: the panel tells you what, and the bar tells you whether to look.
BarWidget {
  id: root
  moduleName: "brightwalker25.kbullet"

  // nf-md-notebook. Present in JetBrainsMono Nerd Font, which is what the bar
  // falls back to when a chosen font lacks the private-use range.
  readonly property string glyph: "󰠮"

  readonly property bool showCount: setting("showCount", true) === true
  readonly property int openCount: panelLoader.item ? panelLoader.item.openCount : 0
  readonly property int urgentCount: panelLoader.item ? panelLoader.item.urgentCount : 0
  readonly property bool hasJournal: panelLoader.item ? panelLoader.item.hasJournal : false

  readonly property string label: (showCount && openCount > 0)
    ? glyph + " " + openCount
    : glyph

  readonly property string tip: {
    if (!hasJournal) return "Nothing written yet"
    var t = openCount + " open"
    if (urgentCount > 0) t += " · " + urgentCount + " urgent"
    return t
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.poll) panelLoader.item.poll()
  }

  function openApp() {
    if (panelLoader.item && panelLoader.item.openKbullet) panelLoader.item.openKbullet()
  }

  // Shape contract for shell.summon/hide/toggle routing: Bar.findPanelWidget
  // needs open/close/opened on the bar-widget root, not on the nested panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // The bar prefers closeForPopoutSwitch over close when handing one panel
  // over to another, and reads popoutSwitchClosing back off the owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // WidgetButton rather than BarIconButton, because the label carries a count
  // alongside the glyph and because WidgetButton registers itself as a bar
  // click target. Without that registration, the widget would not receive the
  // click that the bar forwards when another panel is already open.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    fontSize: Style.font.body
    // Paints the bar's urgent colour. Reserved for a genuine `!` entry, so it
    // never becomes decoration.
    active: root.urgentCount > 0
    tooltipText: root.tip

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else if (b === Qt.RightButton) root.openApp()
      else root.togglePanel()
    }
  }
}
