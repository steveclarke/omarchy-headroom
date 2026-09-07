import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Pace.js" as Pace

Panel {
  id: root
  moduleName: "io.github.steveclarke.headroom"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property double now: service ? service.nowMs : Date.now()
  readonly property var providers: service ? service.providers : [Model.empty("claude"), Model.empty("codex")]
  readonly property color surface: Color.popups.background
  readonly property color foreground: Color.popups.text
  readonly property color dim: legible(mix(foreground, surface, 0.22))
  readonly property color urgent: legible(Color.urgent)
  readonly property color caution: legible(Qt.hsla(0.105, 0.72, surface.hslLightness > 0.5 ? 0.34 : 0.65, 1))
  readonly property color calm: legible(mix(Color.accent, foreground, 0.2))
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  function mix(a, b, amount) {
    return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1)
  }
  function luminance(c) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  }
  function legible(c) {
    var background = luminance(surface)
    for (var step = 0; step <= 10; step++) {
      var candidate = mix(c, foreground, step / 10)
      var ink = luminance(candidate)
      if ((Math.max(ink, background) + 0.05) / (Math.min(ink, background) + 0.05) >= 4.5) return candidate
    }
    return foreground
  }
  function refresh() { if (service) service.refresh() }
  function severity(forecast) {
    if (!forecast) return foreground
    if (forecast.status === "urgent" || forecast.status === "exhausted") return urgent
    return forecast.status === "caution" ? caution : calm
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: keys
    padding: Style.spacing.panelPadding
    contentWidth: panel.fittedContentWidth(Style.space(344))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(680))
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { if (root.bar) root.bar.switchPanelFrom(root.hostWidget || root, direction) }
      onTextKey: function(t) { if (t.toLowerCase() === "r") root.refresh() }
      onActivateRequested: root.refresh()
      onMoveRequested: function(dx, dy) { scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + dy * Style.space(40))) }
      Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: content
          width: scroll.width
          spacing: Style.space(20)
          Repeater {
            model: root.providers
            Column {
              id: card
              required property var modelData
              required property int index
              width: content.width
              spacing: Style.space(16)
              PanelSeparator { width: parent.width; visible: card.index > 0 }
              Item {
                width: parent.width
                height: Math.max(providerIcon.height, providerName.height, planName.height)
                Image {
                  id: providerIcon
                  source: Qt.resolvedUrl("assets/" + card.modelData.id + (card.modelData.id === "codex" && root.foreground.hslLightness < 0.5 ? "-light" : "") + ".svg")
                  width: Style.space(22)
                  height: width
                  sourceSize.width: width * 2
                  sourceSize.height: height * 2
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: providerName
                  anchors.left: providerIcon.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: planName.left
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: card.modelData.name
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.weight: Font.DemiBold
                }
                Text {
                  id: planName
                  anchors.right: parent.right
                  anchors.baseline: providerName.baseline
                  width: Math.min(implicitWidth, parent.width * 0.28)
                  text: card.modelData.plan || "Usage limits"
                  elide: Text.ElideRight
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  textFormat: Text.PlainText
                }
              }
              Text {
                width: parent.width
                text: Model.message(card.modelData, root.now)
                visible: text !== ""
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Repeater {
                model: card.modelData.windows
                Column {
                  id: metric
                  required property var modelData
                  width: card.width
                  spacing: Style.space(4)
                  readonly property var forecast: Pace.evaluate(modelData, card.modelData.observedAt, root.now, Model.fresh(card.modelData, root.now))
                  readonly property string remaining: Model.percentage(modelData, root.now)
                  Accessible.role: Accessible.ProgressBar
                  Accessible.name: modelData.title + ": " + remaining + (remaining !== "—" ? " remaining. " : ". ") + Pace.summary(forecast, root.now)
                  Item {
                    width: parent.width
                    height: percent.height
                    Text {
                      anchors.left: parent.left
                      anchors.right: capacity.left
                      anchors.rightMargin: Style.space(12)
                      anchors.baseline: capacity.baseline
                      text: metric.modelData.title
                      elide: Text.ElideRight
                      textFormat: Text.PlainText
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                    Row {
                      id: capacity
                      anchors.right: parent.right
                      baselineOffset: percent.baselineOffset
                      spacing: Style.space(5)
                      Text {
                        id: percent
                        text: metric.remaining
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.heading
                        font.weight: Font.DemiBold
                      }
                      Text {
                        anchors.baseline: percent.baseline
                        text: "left"
                        visible: metric.remaining !== "—"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                  Item {
                    width: parent.width
                    height: Style.space(12)
                    Rectangle {
                      id: track
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width
                      height: Style.space(6)
                      radius: height / 2
                      color: Style.selectedFillFor(root.foreground, Color.accent)
                    }
                    Rectangle {
                      anchors.left: track.left; anchors.verticalCenter: track.verticalCenter
                      height: track.height; radius: height / 2
                      width: metric.remaining === "—" ? 0 : track.width * Math.max(0, Math.min(1, 1 - metric.modelData.used))
                      color: root.severity(metric.forecast)
                      opacity: Model.fresh(card.modelData, root.now) ? 1 : 0.4
                      Behavior on width {
                        enabled: root.opened && Model.fresh(card.modelData, root.now)
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                      }
                    }
                    Rectangle {
                      visible: metric.forecast !== null && metric.forecast.marker !== null
                      width: Style.space(3); height: parent.height
                      x: Math.max(0, Math.min(parent.width - width, parent.width * (metric.forecast ? 1 - metric.forecast.marker : 0)))
                      color: root.surface
                      Rectangle { anchors.centerIn: parent; width: Style.space(1); height: parent.height; color: root.foreground }
                    }
                    MouseArea {
                      anchors.fill: parent; hoverEnabled: true
                      onEntered: if (root.bar) root.bar.showTooltip(this, metric.modelData.title + "\n" + Pace.tooltip(metric.forecast))
                      onExited: if (root.bar) root.bar.hideTooltip(this)
                    }
                  }
                  Item {
                    id: details
                    width: parent.width
                    readonly property bool stacked: resetText.implicitWidth + forecastText.implicitWidth + Style.space(12) > width
                    height: stacked && forecastText.text !== "" ? resetText.height + forecastText.height + Style.space(4) : Math.max(resetText.height, forecastText.height)
                    Text {
                      id: resetText
                      width: details.stacked ? parent.width : parent.width - forecastText.width - Style.space(12)
                      text: metric.modelData.resetAt > root.now ? "Resets in " + Pace.duration(metric.modelData.resetAt - root.now) : metric.modelData.resetAt > 0 ? "Awaiting reset update" : "Reset not reported"
                      wrapMode: Text.WordWrap
                      color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    }
                    Text {
                      id: forecastText
                      width: Math.min(implicitWidth, parent.width)
                      x: details.stacked ? 0 : parent.width - width
                      y: details.stacked ? resetText.height + Style.space(4) : 0
                      text: (metric.forecast && (metric.forecast.status === "urgent" || metric.forecast.status === "exhausted") ? "󰈸 " : "") + Pace.summary(metric.forecast, root.now)
                      wrapMode: Text.WordWrap
                      color: metric.forecast && metric.forecast.status !== "calm" ? root.severity(metric.forecast) : root.dim
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      font.weight: metric.forecast && metric.forecast.status !== "calm" ? Font.DemiBold : Font.Normal
                    }
                  }
                }
              }
            }
          }
          PanelSeparator { width: parent.width }
          Row {
            width: parent.width
            Text {
              width: parent.width - refreshButton.width
              anchors.verticalCenter: parent.verticalCenter
              text: root.service && root.service.demoMode !== "" ? "Headroom · sample data" : root.service && root.service.refreshing ? "Checking usage…" : "Headroom · remaining capacity"
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            PanelActionButton {
              id: refreshButton
              iconText: "󰑐"
              tooltipText: "Refresh usage (R)"
              foreground: root.foreground
              Accessible.role: Accessible.Button
              Accessible.name: "Refresh usage"
              enabled: root.service !== null && !root.service.refreshing
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}
