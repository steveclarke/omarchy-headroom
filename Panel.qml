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
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.72)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color caution: "#c49645"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  function refresh() { if (service) service.refresh() }
  function severity(forecast) {
    if (!forecast) return foreground
    if (forecast.status === "urgent" || forecast.status === "exhausted") return urgent
    return forecast.status === "caution" ? caution : Color.accent
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(370))
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
          spacing: Style.space(16)
          Repeater {
            model: root.providers
            Column {
              id: card
              required property var modelData
              required property int index
              width: content.width
              spacing: Style.space(12)
              PanelSeparator { width: parent.width; visible: card.index > 0 }
              Row {
                width: parent.width
                spacing: Style.space(10)
                Image {
                  source: Qt.resolvedUrl("assets/" + card.modelData.id + (card.modelData.id === "codex" && root.foreground.hslLightness < 0.5 ? "-light" : "") + ".svg")
                  width: Style.font.title
                  height: width
                  sourceSize.width: width * 2
                  sourceSize.height: height * 2
                  anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                  spacing: Style.space(2)
                  Text { text: card.modelData.name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { text: card.modelData.plan || "Usage limits"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; textFormat: Text.PlainText }
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
                  spacing: Style.space(5)
                  readonly property var forecast: Pace.evaluate(modelData, card.modelData.observedAt, root.now, Model.fresh(card.modelData, root.now))
                  Row {
                    width: parent.width
                    Text { width: parent.width - percent.width; text: metric.modelData.title; elide: Text.ElideRight; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                    Text { id: percent; text: Model.percentage(metric.modelData, root.now) === "—" ? "—" : Model.percentage(metric.modelData, root.now) + " left"; color: root.severity(metric.forecast); font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  }
                  Item {
                    width: parent.width
                    height: Style.space(9)
                    Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Style.space(4); radius: height / 2; color: Style.selectedFillFor(root.foreground, Color.accent) }
                    Rectangle {
                      anchors.left: track.left; anchors.verticalCenter: track.verticalCenter
                      height: track.height; radius: height / 2
                      width: track.width * Math.max(0, Math.min(1, 1 - metric.modelData.used))
                      color: root.severity(metric.forecast)
                      opacity: Model.fresh(card.modelData, root.now) ? 1 : 0.4
                    }
                    Rectangle {
                      visible: metric.forecast !== null && metric.forecast.marker !== null
                      width: Style.space(2); height: parent.height
                      x: Math.max(0, Math.min(parent.width - width, parent.width * (metric.forecast ? 1 - metric.forecast.marker : 0)))
                      color: root.foreground
                    }
                    MouseArea {
                      anchors.fill: parent; hoverEnabled: true
                      onEntered: if (root.bar) root.bar.showTooltip(this, Pace.tooltip(metric.forecast))
                      onExited: if (root.bar) root.bar.hideTooltip(this)
                    }
                  }
                  Row {
                    width: parent.width
                    Text {
                      width: parent.width - forecastText.width
                      text: metric.modelData.resetAt > root.now ? "Resets in " + Pace.duration(metric.modelData.resetAt - root.now) : metric.modelData.resetAt > 0 ? "Awaiting reset update" : "Reset not reported"
                      color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    }
                    Text {
                      id: forecastText
                      text: (metric.forecast && (metric.forecast.status === "urgent" || metric.forecast.status === "exhausted") ? "󰈸 " : "") + Pace.summary(metric.forecast, root.now)
                      color: root.severity(metric.forecast); font.family: root.fontFamily; font.pixelSize: Style.font.caption
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
            }
            PanelActionButton {
              id: refreshButton
              iconText: "󰑐"
              tooltipText: "Refresh usage (R)"
              foreground: root.foreground
              enabled: root.service !== null && !root.service.refreshing
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}
