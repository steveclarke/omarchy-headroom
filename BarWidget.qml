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
    tooltipText: "Headroom · percentages remaining\nS: Session · W: Weekly\nClick for limits and forecasts · right-click to refresh"
    Accessible.role: Accessible.Button
    Accessible.name: "Headroom. " + root.providers.map(function(p) {
      return p.name + ": session " + Model.percentage(Model.find(p, "session"), root.now)
        + ", weekly " + Model.percentage(Model.find(p, "weekly"), root.now) + " remaining"
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
          required property int index
          spacing: Style.space(6)
          Rectangle {
            visible: chip.index > 0 && !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(1)
            height: Style.space(12)
            color: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.22)
          }
          Image {
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("assets/" + chip.modelData.id + (chip.modelData.id === "codex" && button.foreground.hslLightness < 0.5 ? "-light" : "") + ".svg")
            width: Style.font.icon
            height: width
            sourceSize.width: width * 2
            sourceSize.height: height * 2
          }
          Grid {
            columns: root.vertical ? 1 : 2
            spacing: Style.space(7)
            Repeater {
              model: ["session", "weekly"]
              Row {
                id: reading
                required property string modelData
                spacing: Style.space(3)
                Text {
                  text: reading.modelData === "session" ? "S" : "W"
                  anchors.baseline: value.baseline
                  color: button.foreground
                  font.family: button.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  id: value
                  width: Math.ceil(valueSize.width)
                  text: Model.percentage(Model.find(chip.modelData, reading.modelData), root.now)
                  horizontalAlignment: Text.AlignRight
                  color: button.foreground
                  font.family: button.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.DemiBold
                }
                TextMetrics {
                  id: valueSize
                  text: "100%"
                  font: value.font
                }
              }
            }
          }
          Text {
            text: root.warning(chip.modelData)
            width: Style.font.iconSmall
            anchors.verticalCenter: parent.verticalCenter
            color: text === "!" ? button.foreground : root.bar ? root.bar.urgent : Color.urgent
            font.family: button.fontFamily
            font.pixelSize: Style.font.iconSmall
          }
        }
      }
    }
  }
}
