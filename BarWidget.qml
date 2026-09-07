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
      if (p.windows[i].id !== "weekly" && p.windows[i].id !== "fable-weekly") continue
      var f = Pace.evaluate(p.windows[i], p.observedAt, now, true)
      if (f && (f.status === "urgent" || f.status === "exhausted")) return "󰈸"
    }
    return ""
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: Math.round(chips.implicitWidth)
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
    labelVisible: false
    fixedWidth: root.vertical ? -1 : chips.implicitWidth + Style.space(16)
    fixedHeight: root.vertical ? chips.implicitHeight + Style.space(12) : -1
    tooltipText: "Headroom · weekly percentages remaining\nClick for costs, limits and forecasts · right-click to refresh"
    Accessible.role: Accessible.Button
    Accessible.name: "Headroom. " + root.providers.map(function(p) {
      return p.name + ": weekly " + Model.percentage(Model.find(p, "weekly"), root.now) + " remaining"
    }).join(". ")
    Accessible.onPressAction: root.toggle()
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (root.service) root.service.refresh()
    }
    Grid {
      id: chips
      x: Math.round((parent.width - implicitWidth) / 2)
      anchors.verticalCenter: parent.verticalCenter
      columns: root.vertical ? 1 : 2
      spacing: Style.space(12)
      Repeater {
        model: root.providers
        Row {
          id: chip
          required property var modelData
          spacing: Style.space(6)
          TintedIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconSource: Qt.resolvedUrl("assets/" + (chip.modelData.id === "codex" ? "openai" : "claude") + ".svg")
            ink: button.foreground
            width: Style.bar.iconCanvas
            height: width
          }
          Text {
            textFormat: Text.PlainText
            id: value
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(valueSize.width)
            text: Model.percentage(Model.find(chip.modelData, "weekly"), root.now)
            horizontalAlignment: Text.AlignRight
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
            TextMetrics { id: valueSize; text: "100%"; font: value.font }
          }
          Text {
            textFormat: Text.PlainText
            text: root.warning(chip.modelData)
            visible: text !== ""
            width: Style.bar.iconCanvas
            anchors.verticalCenter: parent.verticalCenter
            color: text === "!" ? button.foreground : root.bar ? root.bar.urgent : Color.urgent
            font.family: button.fontFamily
            font.pixelSize: Style.bar.iconFont
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }
}
