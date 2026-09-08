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
  readonly property var providers: service ? service.barProviders : []
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function activate() {
    toggle()
    if (opened && service && !service.selectedIds.length) showSettings()
  }
  function showSettings() { if (panelLoader.item) panelLoader.item.showSettings() }
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
      if (p.warningWindows.indexOf(p.windows[i].id) < 0) continue
      var f = Pace.evaluate(p.windows[i], p.observedAt, now, true)
      if (f && (f.status === "urgent" || f.status === "exhausted")) return "󰈸"
    }
    return ""
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: Math.round(root.providers.length ? chips.implicitWidth : fallback.implicitWidth)
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
    fixedWidth: root.vertical ? -1 : (root.providers.length ? chips.implicitWidth : fallback.implicitWidth) + Style.space(16)
    fixedHeight: root.vertical && root.providers.length ? chips.implicitHeight + Style.space(12) : -1
    // The panel is the detail view; hovering keeps the bar unobstructed.
    tooltipText: ""
    Accessible.role: Accessible.Button
    Accessible.name: root.providers.length ? "Headroom. " + root.providers.map(function(p) {
      return p.name + ": weekly " + Model.percentage(Model.find(p, p.headline), root.now) + " remaining"
    }).join(". ") : "Headroom. Open usage details and settings."
    Accessible.onPressAction: root.activate()
    onPressed: function(b) {
      if (b === Qt.LeftButton) {
        root.activate()
      }
      else if (root.service) root.service.refresh()
    }
    Text {
      id: fallback
      textFormat: Text.PlainText
      visible: root.providers.length === 0
      anchors.centerIn: parent
      text: "Headroom"
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      color: button.foreground
      renderType: Text.NativeRendering
    }
    Grid {
      id: chips
      x: Math.round((parent.width - implicitWidth) / 2)
      anchors.verticalCenter: parent.verticalCenter
      columns: root.vertical ? 1 : Math.max(1, root.providers.length)
      spacing: Style.space(12)
      Repeater {
        model: root.providers
        Row {
          id: chip
          required property var modelData
          spacing: Style.space(6)
          TintedIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconSource: Qt.resolvedUrl("assets/" + chip.modelData.icon)
            ink: button.foreground
            width: Style.bar.iconCanvas
            height: width
          }
          Text {
            textFormat: Text.PlainText
            id: value
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(valueSize.width)
            text: Model.percentage(Model.find(chip.modelData, chip.modelData.headline), root.now)
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
