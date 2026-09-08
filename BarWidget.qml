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
  function providerTooltip(p) {
    var fresh = Model.fresh(p, now)
    var lines = [p.name + (!fresh && p.windows.length ? " · Outdated" : "")]
    if (!p.windows.length) return lines.concat([Model.message(p, now) || "Usage unavailable"]).join("\n")

    var weekly = Model.find(p, "weekly")
    var remaining = Model.percentage(weekly, now)
    var headline = "Weekly " + remaining + (remaining === "—" ? "" : " left")
    if (weekly && weekly.resetAt > now)
      headline += " · resets in " + Pace.duration(weekly.resetAt - now)
    lines.push(headline)

    var details = []
    for (var i = 0; i < p.windows.length; i++) {
      var w = p.windows[i]
      if (w.id === "weekly") continue
      var label = w.id === "fable-weekly" ? "Fable" : w.title
      var value = Model.percentage(w, now)
      details.push(label + " " + value + (value === "—" ? "" : " left"))
    }
    if (details.length) lines.push(details.join(" · "))

    for (var j = 0; j < p.windows.length; j++) {
      var window = p.windows[j]
      var forecast = Pace.evaluate(window, p.observedAt, now, fresh)
      if (!forecast || forecast.status === "calm") continue
      var icon = forecast.status === "caution" ? "󰔟" : "󰈸"
      var note = Pace.summary(forecast, now)
      lines.push(icon + " " + window.title + (note ? " · " + note : ""))
    }
    var message = Model.message(p, now)
    if (message && fresh) lines.push(message)
    return lines.join("\n")
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
    tooltipText: (root.service && root.service.demoMode ? "Sample data\n\n" : "")
      + root.providers.map(function(p) { return root.providerTooltip(p) }).join("\n\n")
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
