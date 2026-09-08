pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "Model.js" as Model
import "Pace.js" as Pace
import "Costs.js" as Costs
import "Providers.js" as Providers

Panel {
  id: root
  moduleName: "io.github.steveclarke.headroom"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property double now: service ? service.nowMs : Date.now()
  readonly property var providers: service ? service.providers : []
  readonly property var costs: service ? service.costs : Costs.empty([])
  readonly property int period: service ? service.costPeriod : 0
  readonly property color surface: Color.popups.background
  readonly property color foreground: Color.popups.text
  readonly property color group: surface
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property color dim: legible(mix(foreground, surface, 0.22), surface)
  readonly property color urgent: legible(Color.urgent, group)
  readonly property color caution: surface.hslLightness > 0.5 ? "#c49a16" : "#edc35b"
  readonly property color cautionIcon: surface.hslLightness > 0.5 ? "#916900" : caution
  property bool settingsOpen: false
  property string orderError: ""
  ProviderReorder {
    id: detailDrag
    container: content; repeater: providerRepeater
    onMoved: function(id, target, after) {
      root.orderError = root.service && root.service.savePreferences(Providers.reordered(root.service.preferences, id, target, after))
        ? "" : "Could not save this order. Try again."
      Qt.callLater(keys.forceActiveFocus)
    }
  }
  readonly property var costProviders: service ? service.costIds.map(function(id) { return Providers.find(root.service.catalog, id) }) : []
  readonly property var costAmounts: costProviders.map(function(p) { return Costs.amount(root.costs, p.id, root.period, root.now) })
  function showSettings() { if (service) { settingsOpen = true; detailDrag.cancel(); scroll.contentY = 0; settingsView.begin() } }
  function hideSettings() { settingsOpen = false; scroll.contentY = 0; keys.forceActiveFocus() }
  onOpenedChanged: if (!opened) { settingsOpen = false; detailDrag.cancel(); orderError = "" }
  readonly property var costTotal: Costs.total(costs, period, now)
  readonly property string costMessage: Costs.message(costs, now)
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
  function money(value) { return value === null ? "—" : "$" + Number(value).toLocaleString(Qt.locale("en_US"), 'f', 2) }
  function refresh() { if (service) service.refresh() }
  function selectPeriod(index) { if (service) service.costPeriod = Math.max(0, Math.min(2, index)) }
  function meterColor(severity) {
    return severity === "critical" ? urgent : severity === "warning" ? caution : Color.accent
  }
  component Label: Text {
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: root.settingsOpen ? settingsView : keys
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(1000))
    PanelKeyCatcher {
      id: keys
      blocked: root.settingsOpen || detailDrag.active || detailDrag.keyboardFocus
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { if (root.bar) root.bar.switchPanelFrom(root.hostWidget || root, direction) }
      onTextKey: function(t) {
        if (t.toLowerCase() === "r") root.refresh()
        if (t.toLowerCase() === "s") root.showSettings()
        if (["1", "2", "3"].indexOf(t) >= 0) root.selectPeriod(Number(t) - 1)
      }
      onActivateRequested: root.refresh()
      onMoveRequested: function(dx, dy) {
        if (dx) root.selectPeriod(root.period + dx)
        else scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + dy * Style.space(40)))
      }
      Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !detailDrag.active
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: content
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
          Label {
            visible: !root.settingsOpen && !root.providers.length
            width: parent.width
            text: !root.service || !root.service.catalog.length ? "Headroom is unavailable. Check its installation." : "No providers enabled. Choose providers in Settings."
            wrapMode: Text.WordWrap
          }
          Column {
            visible: !root.settingsOpen && root.costProviders.length > 0
            width: parent.width
            spacing: Style.space(10)
            Row {
              spacing: Style.space(8)
              Label { text: "Cost"; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold }
              TintedIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(14); height: width
                iconSource: Qt.resolvedUrl("assets/info.svg")
                ink: root.dim
                Accessible.role: Accessible.StaticText
                Accessible.name: "Costs are estimated API-equivalent usage value in USD from this machine's local history, not subscription charges."
                MouseArea {
                  anchors.fill: parent; hoverEnabled: true
                  onEntered: if (root.bar) root.bar.showTooltip(this, "Estimated API-equivalent value in USD.\nLocal history on this machine; not subscription charges.\n30 Days includes today and the previous 29 calendar days.")
                  onExited: if (root.bar) root.bar.hideTooltip(this)
                }
              }
            }
            Item {
              width: parent.width
              height: costContent.implicitHeight
              Column {
                id: costContent
                width: parent.width
                spacing: Style.space(16)
                Row {
                  spacing: Style.spacing.md
                  Repeater {
                    model: ["Today", "Yesterday", "30 Days"]
                    Ui.Button {
                      required property string modelData
                      required property int index
                      text: modelData
                      selected: root.period === index
                      bordered: true
                      foreground: root.foreground
                      background: root.surface
                      Accessible.role: Accessible.PageTab
                      Accessible.name: text
                      Accessible.selected: selected
                      Accessible.description: "Cost period. Use left/right arrows or keys 1, 2, 3."
                      onClicked: root.selectPeriod(index)
                    }
                  }
                }
                Item {
                  width: parent.width; height: Style.space(134)
                  Item {
                    id: ringArea
                    width: Style.space(134); height: width
                    Canvas {
                      id: ring
                      anchors.fill: parent
                      property var amounts: root.costAmounts
                      property color emptyColor: root.track
                      onAmountsChanged: requestPaint()
                      onEmptyColorChanged: requestPaint()
                      onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var center = width / 2, radius = center - Style.space(13)
                        ctx.lineWidth = Style.space(24)
                        var sum = amounts.some(function(a) { return a === null }) ? 0 : amounts.reduce(function(a, b) { return a + b }, 0)
                        ctx.strokeStyle = emptyColor
                        ctx.beginPath(); ctx.arc(center, center, radius, 0, 2 * Math.PI); ctx.stroke()
                        if (sum <= 0) return
                        var start = -Math.PI / 2, colors = root.costProviders.map(function(p) { return p.color })
                        var segments = amounts.filter(function(a) { return a > 0 }).length
                        for (var i = 0; i < amounts.length; i++) {
                          var sweep = amounts[i] / sum * 2 * Math.PI
                          if (sweep > 0) {
                            var gap = segments > 1 ? Math.min(0.018, sweep / 4) : 0
                            ctx.strokeStyle = colors[i]
                            ctx.beginPath(); ctx.arc(center, center, radius, start + gap, start + sweep - gap); ctx.stroke()
                          }
                          start += sweep
                        }
                      }
                    }
                    Column {
                      anchors.centerIn: parent
                      width: parent.width - Style.space(54)
                      Label {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: root.costTotal === null ? "—" : "$" + Math.round(root.costTotal).toLocaleString(Qt.locale("en_US"), 'f', 0)
                        font.pixelSize: Style.font.display; font.weight: Font.DemiBold
                        minimumPixelSize: Style.space(12); fontSizeMode: Text.Fit
                      }
                      Label {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: "USD"; color: root.dim; font.pixelSize: Style.font.bodySmall
                      }
                    }
                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Total estimated usage value: " + root.money(root.costTotal) + " USD. " + root.costMessage
                  }
                  Column {
                    x: ringArea.width + Style.space(18)
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(12)
                    Repeater {
                      model: root.costProviders
                      Item {
                        id: legendRow
                        required property var modelData
                        required property int index
                        width: parent.width; height: Style.space(20)
                        Rectangle {
                          id: dot
                          width: Style.space(9); height: width; radius: width/2
                          anchors.verticalCenter: parent.verticalCenter
                          color: legendRow.modelData.color
                        }
                        Label {
                          anchors.left: dot.right; anchors.leftMargin: Style.space(7)
                          anchors.verticalCenter: parent.verticalCenter
                          text: legendRow.modelData.shortName; font.pixelSize: Style.font.body
                        }
                        Label {
                          width: Math.min(implicitWidth, parent.width * 0.52)
                          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                          text: root.money(root.costAmounts[legendRow.index])
                          font.pixelSize: Style.font.body
                          minimumPixelSize: Style.space(10); fontSizeMode: Text.Fit
                          horizontalAlignment: Text.AlignRight
                          color: root.dim
                        }
                      }
                    }
                  }
                }
              }
            }
            Label {
              width: parent.width
              text: root.costMessage
              color: root.dim; font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
          Repeater {
            id: providerRepeater
            model: root.settingsOpen ? [] : root.providers
            Item {
              id: providerGroup
              required property var modelData
              required property int index
              readonly property string providerId: modelData.id
              z: detailDrag.dragged === providerGroup && detailDrag.active ? 1 : 0
              opacity: detailDrag.active && detailDrag.dragged !== providerGroup ? 0.45 : 1
              transform: Translate { y: detailDrag.dragged === providerGroup ? detailDrag.offset : 0 }
              width: content.width
              height: providerLayout.implicitHeight
              Rectangle { anchors.fill: parent; color: root.surface; visible: detailDrag.dragged === providerGroup && detailDrag.active }
              Column {
                id: providerLayout
                width: parent.width
                spacing: Style.spacing.panelGap
                PanelSeparator { visible: providerGroup.index > 0 || root.costProviders.length > 0; foreground: root.foreground }
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
                      iconSource: Qt.resolvedUrl("assets/" + providerGroup.modelData.icon); ink: root.dim
                      width: Style.space(21); height: width
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                      id: providerName
                      text: providerGroup.modelData.shortName
                      font.pixelSize: Style.font.heading; font.weight: Font.DemiBold
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                      width: Math.max(0, parent.width - providerName.width - providerIcon.width - Style.space(21))
                      text: providerGroup.modelData.plan
                      elide: Text.ElideRight
                      anchors.baseline: providerName.baseline
                      color: root.dim; font.pixelSize: Style.font.body
                    }
                  }
                  ProviderDragHandle {
                    objectName: "reorder-main-" + providerGroup.providerId
                    width: parent.width; height: parent.height
                    reorder: detailDrag; providerItem: providerGroup; providerName: providerGroup.modelData.shortName
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
                    Label {
                      width: parent.width
                      text: Model.message(providerGroup.modelData, root.now)
                      visible: text !== ""
                      wrapMode: Text.WordWrap
                      color: root.dim; font.pixelSize: Style.font.bodySmall
                    }
                    Repeater {
                      model: providerGroup.modelData.windows
                      Column {
                        id: metric
                        required property var modelData
                        width: quotas.width
                        spacing: Style.space(5)
                        readonly property var forecast: Pace.evaluate(modelData, providerGroup.modelData.observedAt, root.now, Model.fresh(providerGroup.modelData, root.now))
                        readonly property string remaining: Model.percentage(modelData, root.now)
                        readonly property bool flame: forecast !== null && (forecast.status === "urgent" || forecast.status === "exhausted")
                        readonly property var paceMarker: Pace.marker(forecast)
                        Accessible.role: Accessible.ProgressBar
                        Accessible.name: modelData.title + ": " + remaining + " remaining. " + (flame && Pace.summary(forecast, root.now) === "" ? "Will reach limit" : Pace.summary(forecast, root.now))
                        Item {
                          width: parent.width
                          height: Math.max(quotaTitle.height, warning.implicitHeight)
                          Label {
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
                              Label {
                                visible: metric.flame || (metric.forecast !== null && metric.forecast.status === "caution")
                                text: metric.flame ? "󰈸" : "󰔟"
                                color: metric.flame ? root.urgent : root.cautionIcon
                                font.family: Style.font.family
                                font.pixelSize: Style.font.heading
                                anchors.verticalCenter: parent.verticalCenter
                              }
                              Label {
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
                            color: root.meterColor(Pace.severity(metric.modelData, metric.forecast, root.now, Model.fresh(providerGroup.modelData, root.now)))
                            opacity: Model.fresh(providerGroup.modelData, root.now) ? 1 : 0.4
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
                          Label {
                            id: remainingText
                            text: metric.remaining + (metric.remaining === "—" ? "" : " left")
                          }
                          Label {
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
          Label {
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
              Label { text: "Headroom"; font.pixelSize: Style.font.bodySmall; color: root.dim }
              Label {
                width: parent.width
                text: root.service && root.service.demoMode !== "" ? "Sample data" : root.service && (root.service.refreshing || root.service.costsRefreshing) ? "Updating usage…" : "Refreshes every 5 min"
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
              enabled: root.service !== null && root.providers.length > 0 && !root.service.refreshing && !root.service.costsRefreshing
              Accessible.name: "Refresh usage"
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}
