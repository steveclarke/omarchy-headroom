pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import qs.Ui as Ui
import "Model.js" as Model
import "Pace.js" as Pace
import "Providers.js" as Providers

Panel {
  id: root
  moduleName: "io.github.steveclarke.headroom"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property bool anchorCaptured: false
  // Keep the popup steady while visibility changes resize/reposition its bar button.
  readonly property Item heldAnchor: Item {
    parent: root.anchorItem && root.anchorItem.QsWindow.window ? root.anchorItem.QsWindow.window.contentItem : null
  }
  function captureAnchor() {
    if (!anchorItem || !heldAnchor.parent) { anchorCaptured = false; return }
    var position = anchorItem.mapToItem(heldAnchor.parent, 0, 0)
    heldAnchor.x = position.x; heldAnchor.y = position.y
    heldAnchor.width = anchorItem.width; heldAnchor.height = anchorItem.height
    anchorCaptured = true
  }
  onAnchorItemChanged: anchorCaptured = false
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property double now: service ? service.nowMs : Date.now()
  readonly property var providers: service ? service.providers : []
  readonly property color surface: Commons.Color.popups.background
  readonly property color foreground: Commons.Color.popups.text
  readonly property color group: surface
  readonly property color track: Style.selectedFillFor(foreground, Commons.Color.accent)
  readonly property color dim: legible(mix(foreground, surface, 0.22), surface)
  readonly property color urgent: legible(Commons.Color.urgent, group)
  readonly property color caution: surface.hslLightness > 0.5 ? "#c49a16" : "#edc35b"
  readonly property color cautionIcon: surface.hslLightness > 0.5 ? "#916900" : caution
  property bool settingsOpen: false
  property string orderError: ""
  ProviderReorder {
    id: detailDrag
    container: panelContent; repeater: providerRepeater
    onMoved: function(id, target, after) {
      root.orderError = root.service && root.service.savePreferences(Providers.reordered(root.service.preferences, id, target, after))
        ? "" : "Could not save this order. Try again."
      Qt.callLater(keys.forceActiveFocus)
    }
  }
  function showSettings() { if (service) { settingsOpen = true; detailDrag.cancel(); scroll.contentY = 0; settingsView.begin() } }
  function hideSettings() { settingsOpen = false; scroll.contentY = 0; keys.forceActiveFocus() }
  onOpenedChanged: {
    if (opened) captureAnchor()
    else { settingsOpen = false; detailDrag.cancel(); orderError = "" }
  }
  function mix(a, b, amount) {
    var first = Qt.color(a), second = Qt.color(b)
    return Qt.rgba(first.r + (second.r - first.r) * amount, first.g + (second.g - first.g) * amount, first.b + (second.b - first.b) * amount, 1)
  }
  function luminance(c) {
    var color = Qt.color(c)
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
  }
  function legible(ink, background) {
    var base = luminance(background)
    for (var step = 0; step <= 10; step++) {
      var candidate = mix(ink, foreground, step / 10), light = luminance(candidate)
      if ((Math.max(light, base) + 0.05) / (Math.min(light, base) + 0.05) >= 4.65) return candidate
    }
    return foreground
  }
  function refresh() { if (service) service.refresh() }
  function meterColor(severity) {
    return severity === "critical" ? urgent : severity === "warning" ? caution : Commons.Color.accent
  }
  component PlainLabel: Text {
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorCaptured ? root.heldAnchor : root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: root.settingsOpen ? settingsView : keys
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelContent.implicitHeight, Style.space(1000))
    PanelKeyCatcher {
      id: keys
      blocked: root.settingsOpen || detailDrag.active || detailDrag.keyboardFocus
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { if (root.bar) root.bar.switchPanelFrom(root.hostWidget || root, direction) }
      onTextKey: function(t) {
        if (t.toLowerCase() === "r") root.refresh()
        if (t.toLowerCase() === "s") root.showSettings()
      }
      onActivateRequested: root.refresh()
      onMoveRequested: function(dx, dy) {
        if (dy) scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + dy * Style.space(40)))
      }
      Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !detailDrag.active
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: panelContent
          width: scroll.width
          spacing: Style.spacing.panelGap
          SettingsView {
            id: settingsView
            visible: root.settingsOpen
            width: parent.width
            service: root.service
            ink: root.foreground; dim: root.dim
            onDone: root.hideSettings()
          }
          PlainLabel {
            visible: !root.settingsOpen && !root.providers.length
            width: parent.width
            text: !root.service || !root.service.catalog.length ? "Headroom is unavailable. Check its installation." : "No providers enabled. Choose providers in Settings."
            wrapMode: Text.WordWrap
          }
          Repeater {
            id: providerRepeater
            model: root.settingsOpen || !root.service ? [] : root.service.preferences.providerOrder.filter(function(id) { return !!Providers.find(root.providers, id) })
            Item {
              id: providerGroup
              required property string modelData
              required property int index
              readonly property string providerId: modelData
              readonly property var provider: Providers.find(root.providers, modelData) || {windows: [], icon: "", shortName: "", plan: ""}
              z: detailDrag.dragged === providerGroup && detailDrag.active ? 1 : 0
              opacity: detailDrag.active && detailDrag.dragged !== providerGroup ? 0.45 : 1
              transform: Translate { y: detailDrag.dragged === providerGroup ? detailDrag.offset : 0 }
              width: panelContent.width
              height: sectionLayout.implicitHeight
              Rectangle { anchors.fill: parent; color: root.surface; visible: detailDrag.dragged === providerGroup && detailDrag.active }
              Column {
                id: sectionLayout
                width: parent.width
                spacing: Style.spacing.panelGap
                PanelSeparator { visible: providerGroup.index > 0; foreground: root.foreground }
                Loader {
                  width: parent.width
                  sourceComponent: Component {
                    Column {
                      id: providerLayout
                      width: parent.width
                      spacing: Style.spacing.panelGap
                      Item {
                        width: parent.width
                        height: providerHeader.implicitHeight
                        Row {
                          id: providerHeader
                          x: Style.space(28)
                          width: parent.width - x
                          spacing: Style.space(7)
                          TintedIcon {
                            id: providerIcon
                            iconSource: Qt.resolvedUrl("assets/" + providerGroup.provider.icon); ink: root.dim
                            width: Style.space(21); height: width
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          PlainLabel {
                            id: providerName
                            text: providerGroup.provider.shortName
                            font.pixelSize: Style.font.heading; font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                          }
                          PlainLabel {
                            width: Math.max(0, parent.width - providerName.width - providerIcon.width - Style.space(21))
                            text: providerGroup.provider.plan
                            elide: Text.ElideRight
                            anchors.baseline: providerName.baseline
                            color: root.dim; font.pixelSize: Style.font.body
                          }
                        }
                        ProviderDragHandle {
                          objectName: "reorder-main-" + providerGroup.providerId
                          width: parent.width; height: parent.height
                          reorder: detailDrag; providerItem: providerGroup; providerName: providerGroup.provider.shortName
                          ink: root.dim
                        }
                      }
                      Item {
                        width: parent.width
                        height: quotas.implicitHeight
                        Column {
                          id: quotas
                          width: parent.width
                          spacing: Style.spacing.panelGap
                          PlainLabel {
                            width: parent.width
                            text: Model.message(providerGroup.provider, root.now)
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            color: root.dim; font.pixelSize: Style.font.bodySmall
                          }
                          Repeater {
                            model: providerGroup.provider.windows
                            Column {
                              id: metric
                              required property var modelData
                              width: quotas.width
                              spacing: Style.space(5)
                              readonly property var forecast: Pace.evaluate(modelData, providerGroup.provider.observedAt, root.now, Model.fresh(providerGroup.provider, root.now))
                              readonly property string remaining: Model.percentage(modelData, root.now)
                              readonly property bool flame: forecast !== null && (forecast.status === "urgent" || forecast.status === "exhausted")
                              readonly property var paceMarker: Pace.marker(forecast)
                              Accessible.role: Accessible.ProgressBar
                              Accessible.name: modelData.title + ": " + remaining + " remaining. " + (flame && Pace.summary(forecast, root.now) === "" ? "Will reach limit" : Pace.summary(forecast, root.now))
                              Item {
                                width: parent.width
                                height: Math.max(quotaTitle.height, warning.implicitHeight)
                                PlainLabel {
                                  id: quotaTitle
                                  width: parent.width - (warning.visible ? warning.width + Style.space(10) : 0)
                                  text: metric.modelData.title === "Fable Weekly" ? "Fable" : metric.modelData.title
                                  elide: Text.ElideRight
                                  font.pixelSize: Style.font.title; font.weight: Font.DemiBold
                                }
                                Item {
                                  id: warning
                                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                  implicitWidth: warningContents.implicitWidth
                                  implicitHeight: warningContents.implicitHeight
                                  visible: metric.flame || warningText.text !== ""
                                  Row {
                                    id: warningContents
                                    spacing: Style.space(4)
                                    PlainLabel {
                                      visible: metric.flame || (metric.forecast !== null && metric.forecast.status === "caution")
                                      text: metric.flame ? "󰈸" : "󰔟"
                                      color: metric.flame ? root.urgent : root.cautionIcon
                                      font.family: Style.font.family
                                      font.pixelSize: Style.font.heading
                                      anchors.verticalCenter: parent.verticalCenter
                                    }
                                    PlainLabel {
                                      id: warningText
                                      visible: text !== ""
                                      text: Pace.summary(metric.forecast, root.now)
                                      color: root.dim; font.pixelSize: Style.font.bodySmall
                                      anchors.verticalCenter: parent.verticalCenter
                                    }
                                  }
                                  MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    onEntered: if (root.bar) root.bar.showTooltip(this, Pace.tooltip(metric.forecast))
                                    onExited: if (root.bar) root.bar.hideTooltip(this)
                                  }
                                }
                              }
                              Rectangle {
                                width: parent.width; height: Style.space(6); radius: Math.min(Style.cornerRadius, height / 2)
                                color: root.track
                                Rectangle {
                                  width: metric.remaining === "—" ? 0 : parent.width * Math.max(0, Math.min(1, 1 - metric.modelData.used))
                                  height: parent.height; radius: parent.radius
                                  color: root.meterColor(Pace.severity(metric.modelData, metric.forecast, root.now, Model.fresh(providerGroup.provider, root.now)))
                                  opacity: Model.fresh(providerGroup.provider, root.now) ? 1 : 0.4
                                }
                                Rectangle {
                                  visible: metric.paceMarker !== null
                                  x: Math.max(0, Math.min(parent.width - width, parent.width * (1 - (metric.paceMarker || 0)) - width / 2))
                                  anchors.verticalCenter: parent.verticalCenter
                                  width: Style.space(2); height: parent.height + Style.space(4); radius: Style.space(1)
                                  color: root.mix(root.foreground, root.group, 0.45)
                                }
                                MouseArea {
                                  anchors.fill: parent; anchors.margins: -Style.space(3)
                                  hoverEnabled: true
                                  onEntered: if (root.bar && metric.forecast) root.bar.showTooltip(this, Pace.tooltip(metric.forecast))
                                  onExited: if (root.bar) root.bar.hideTooltip(this)
                                }
                              }
                              Item {
                                width: parent.width
                                height: Math.max(remainingText.height, resetText.height)
                                PlainLabel {
                                  id: remainingText
                                  text: metric.remaining + (metric.remaining === "—" ? "" : " left")
                                }
                                PlainLabel {
                                  id: resetText
                                  anchors.right: parent.right
                                  width: parent.width - remainingText.width - Style.space(10)
                                  horizontalAlignment: Text.AlignRight
                                  text: metric.modelData.resetAt > root.now ? "Resets in " + Pace.duration(metric.modelData.resetAt - root.now) : metric.modelData.resetAt > 0 ? "Awaiting reset update" : "Reset not reported"
                                  wrapMode: Text.WordWrap
                                  color: root.dim; font.pixelSize: Style.font.body
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          PlainLabel {
            visible: !root.settingsOpen && root.orderError !== ""
            width: parent.width; text: root.orderError; wrapMode: Text.WordWrap
          }
          PanelSeparator { visible: !root.settingsOpen; foreground: root.foreground }
          Row {
            visible: !root.settingsOpen
            width: parent.width
            spacing: Style.space(6)
            Column {
              width: parent.width - refreshButton.width - settingsButton.width - Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs
              PlainLabel { text: "Headroom"; font.pixelSize: Style.font.bodySmall; color: root.dim }
              PlainLabel {
                width: parent.width
                objectName: "refresh-countdown"
                text: Model.refreshLabel(root.service, root.now)
                color: root.dim; font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
            Ui.Button {
              id: settingsButton
              Accessible.role: Accessible.Button
              Accessible.name: text
              opacity: enabled ? 1 : 0.5
              text: "Settings"
              iconText: "󰒓"
              foreground: root.foreground; bordered: true; iconSize: Style.font.icon
              enabled: root.service !== null
              onClicked: root.showSettings()
            }
            Ui.Button {
              id: refreshButton
              Accessible.role: Accessible.Button
              opacity: enabled ? 1 : 0.5
              text: "Refresh"
              iconText: "󰑐"
              foreground: root.foreground; bordered: true; iconSize: Style.font.icon
              enabled: root.service !== null && root.providers.length > 0 && !root.service.refreshing
              Accessible.name: "Refresh usage"
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}
