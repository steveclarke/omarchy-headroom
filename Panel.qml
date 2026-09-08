pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
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
  readonly property color surface: Color.popups.background.hslLightness > 0.5 ? mix(Color.popups.background, "white", 0.68) : Color.popups.background
  readonly property color foreground: Color.popups.text
  readonly property color group: mix(surface, foreground, 0.035)
  readonly property color track: mix(group, foreground, 0.14)
  readonly property color dim: legible(mix(foreground, surface, 0.22), mix(group, foreground, 0.055))
  readonly property color urgent: legible(Color.urgent, group)
  readonly property color caution: surface.hslLightness > 0.5 ? "#c49a16" : "#edc35b"
  readonly property color cautionIcon: surface.hslLightness > 0.5 ? "#916900" : caution
  property bool settingsOpen: false
  readonly property var costProviders: service ? service.costIds.map(function(id) { return Providers.find(root.service.catalog, id) }) : []
  readonly property var costAmounts: costProviders.map(function(p) { return Costs.amount(root.costs, p.id, root.period, root.now) })
  function showSettings() { if (service) { settingsOpen = true; scroll.contentY = 0; settingsView.begin() } }
  function hideSettings() { settingsOpen = false; scroll.contentY = 0; keys.forceActiveFocus() }
  onOpenedChanged: if (!opened) settingsOpen = false
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
    font.family: "sans-serif"
    font.pixelSize: Style.space(14)
    textFormat: Text.PlainText
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: root.settingsOpen ? settingsView : keys
    padding: Style.space(18)
    borderSpec: Border.none()
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(1000))
    // Style only this native panel instance. Keep its focus, positioning and
    // dismissal implementation. Guard the host structure for future shells.
    readonly property var cardSurface: keys.parent && keys.parent.parent && "radius" in keys.parent.parent ? keys.parent.parent : null
    PanelKeyCatcher {
      id: keys
      blocked: root.settingsOpen
      Binding { target: panel.cardSurface; property: "radius"; value: Style.space(18); when: panel.cardSurface !== null }
      Binding { target: panel.cardSurface; property: "color"; value: root.surface; when: panel.cardSurface !== null }
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
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: content
          width: scroll.width
          spacing: Style.space(22)
          SettingsView {
            id: settingsView
            visible: root.settingsOpen
            width: parent.width
            service: root.service
            ink: root.foreground; dim: root.dim; surface: root.surface; group: root.group; track: root.track
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
              Label { text: "Cost"; font.pixelSize: Style.space(18); font.weight: Font.DemiBold }
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
            Rectangle {
              width: parent.width
              height: costContent.implicitHeight + Style.space(28)
              radius: Style.space(14)
              color: root.group
              Column {
                id: costContent
                x: Style.space(14); y: x
                width: parent.width - x * 2
                spacing: Style.space(16)
                Rectangle {
                  width: parent.width; height: Style.space(34)
                  radius: height / 2
                  color: root.mix(root.group, root.foreground, 0.055)
                  Rectangle {
                    x: Style.space(3) + root.period * (parent.width - Style.space(6)) / 3
                    y: Style.space(3)
                    width: (parent.width - Style.space(6)) / 3
                    height: parent.height - Style.space(6)
                    radius: height / 2
                    color: root.surface
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  }
                  Row {
                    anchors.fill: parent; anchors.margins: Style.space(3)
                    Repeater {
                      model: ["Today", "Yesterday", "30 Days"]
                      AbstractButton {
                        id: periodButton
                        required property var modelData
                        required property int index
                        width: parent.width / 3; height: parent.height
                        hoverEnabled: true
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData
                        Accessible.description: "Cost period. Use left/right arrows or keys 1, 2, 3."
                        Accessible.selected: root.period === index
                        onClicked: root.selectPeriod(index)
                        contentItem: Label {
                          text: periodButton.modelData
                          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                          font.weight: root.period === periodButton.index ? Font.DemiBold : Font.Normal
                          color: root.period === periodButton.index || periodButton.hovered ? root.foreground : root.dim
                          font.pixelSize: Style.space(13)
                        }
                      }
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
                        font.pixelSize: Style.space(20); font.weight: Font.DemiBold
                        minimumPixelSize: Style.space(12); fontSizeMode: Text.Fit
                      }
                      Label {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: "USD"; color: root.dim; font.pixelSize: Style.space(11)
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
                          text: legendRow.modelData.shortName; font.pixelSize: Style.space(14)
                        }
                        Label {
                          width: Math.min(implicitWidth, parent.width * 0.52)
                          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                          text: root.money(root.costAmounts[legendRow.index])
                          font.pixelSize: Style.space(13)
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
              color: root.dim; font.pixelSize: Style.space(11)
              wrapMode: Text.WordWrap
            }
          }
          Repeater {
            model: root.settingsOpen ? [] : root.providers
            Column {
              id: providerGroup
              required property var modelData
              width: content.width
              spacing: Style.space(9)
              Row {
                width: parent.width
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
                  font.pixelSize: Style.space(18); font.weight: Font.DemiBold
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  width: Math.max(0, parent.width - providerName.width - providerIcon.width - Style.space(21))
                  text: providerGroup.modelData.plan
                  elide: Text.ElideRight
                  anchors.baseline: providerName.baseline
                  color: root.dim; font.pixelSize: Style.space(13)
                }
              }
              Rectangle {
                width: parent.width
                height: quotas.implicitHeight + Style.space(32)
                radius: Style.space(14); color: root.group
                Column {
                  id: quotas
                  x: Style.space(16); y: x
                  width: parent.width - 2 * x
                  spacing: Style.space(22)
                  Label {
                    width: parent.width
                    text: Model.message(providerGroup.modelData, root.now)
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    color: root.dim; font.pixelSize: Style.space(12)
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
                          font.pixelSize: Style.space(16); font.weight: Font.DemiBold
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
                              font.family: "JetBrainsMono Nerd Font"
                              font.pixelSize: Style.space(16)
                              anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                              id: warningText
                              visible: text !== ""
                              text: Pace.summary(metric.forecast, root.now)
                              color: root.dim; font.pixelSize: Style.space(11)
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
                        width: parent.width; height: Style.space(6); radius: height / 2
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
                          color: root.dim; font.pixelSize: Style.space(13)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          Row {
            visible: !root.settingsOpen
            width: parent.width
            spacing: Style.space(6)
            Label {
              width: parent.width - refreshButton.width - settingsButton.width - Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: root.service && root.service.demoMode !== "" ? "Headroom · sample data" : root.service && (root.service.refreshing || root.service.costsRefreshing) ? "Updating usage…" : "Headroom · updates every 5 min"
              color: root.dim; font.pixelSize: Style.space(11)
              wrapMode: Text.WordWrap
            }
            PillButton {
              id: settingsButton
              text: "Settings"
              iconText: "󰒓"
              ink: root.foreground; surface: root.group; hotSurface: root.track
              enabled: root.service !== null
              onClicked: root.showSettings()
            }
            PillButton {
              id: refreshButton
              text: "Refresh"
              iconText: "󰑐"
              ink: root.foreground; surface: root.group; hotSurface: root.track
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
