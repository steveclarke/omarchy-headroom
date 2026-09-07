import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Pace.js" as Pace

// Panel lifecycle follows Omarchy's clock widget (MIT, D. H. Hansson).
BarWidget {
  id: root
  moduleName: "io.github.steveclarke.headroom"
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property double now: service ? service.nowMs : Date.now()
  readonly property var providers: service ? service.providers : [Model.empty("claude"), Model.empty("codex")]
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }
  function warning(p) {
    if (!Model.fresh(p, now)) return "!"
    for (var i = 0; i < p.windows.length; i++) {
      var f = Pace.evaluate(p.windows[i], p.observedAt, now, true)
      if (f && (f.status === "urgent" || f.status === "exhausted")) return "󰈸"
    }
    return ""
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : chips.implicitWidth + Style.space(16)
    fixedHeight: root.vertical ? chips.implicitHeight + Style.space(12) : -1
    tooltipText: "Headroom · percentages remaining\nS: Session · W: Weekly\nClick for limits and forecasts · right-click to refresh"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (root.service) root.service.refresh()
    }
    Grid {
      id: chips
      anchors.centerIn: parent
      columns: root.vertical ? 1 : 2
      spacing: Style.space(12)
      Repeater {
        model: root.providers
        Row {
          id: chip
          required property var modelData
          spacing: Style.space(5)
          opacity: Model.fresh(modelData, root.now) ? 1 : 0.65
          Image {
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("assets/" + chip.modelData.id + (chip.modelData.id === "codex" && button.foreground.hslLightness < 0.5 ? "-light" : "") + ".svg")
            width: Style.font.icon
            height: width
            sourceSize.width: width * 2
            sourceSize.height: height * 2
          }
          Text {
            text: "S " + Model.percentage(Model.find(chip.modelData, "session"), root.now)
              + (root.vertical ? "\n" : "  ") + "W " + Model.percentage(Model.find(chip.modelData, "weekly"), root.now)
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            text: root.warning(chip.modelData)
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: button.fontFamily
            font.pixelSize: Style.font.iconSmall
          }
        }
      }
    }
  }
}
