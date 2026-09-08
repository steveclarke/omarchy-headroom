import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Providers.js" as Providers
import "Model.js" as Model

Column {
  id: root
  required property var service
  required property color ink
  required property color dim
  required property color surface
  required property color group
  required property color track
  readonly property var preferences: service ? service.preferences : Providers.normalize([], {})
  // A stable scalar keeps visibility changes from rebuilding focused controls.
  readonly property string orderKey: preferences.providerOrder.join(",")
  property string error: ""
  signal done()
  spacing: Style.space(18)
  Keys.onEscapePressed: function(event) { root.done(); event.accepted = true }

  function begin() {
    error = ""
    forceActiveFocus()
  }
  function display(id, mode) {
    var next = JSON.parse(JSON.stringify(preferences))
    next.providers[id].display = mode
    apply(next)
  }
  function reorder(id, direction) {
    var next = JSON.parse(JSON.stringify(preferences)), index = next.providerOrder.indexOf(id), target = index + direction
    if (target < 0 || target >= next.providerOrder.length) return
    var other = next.providerOrder[target]
    next.providerOrder[target] = id; next.providerOrder[index] = other
    apply(next)
    // Reordering rebuilds the delegates; keep keyboard navigation in settings.
    Qt.callLater(function() { root.forceActiveFocus() })
  }
  function setCosts(value) {
    apply(Object.assign({}, preferences, {showCosts: value}))
  }
  function apply(value) {
    error = service && service.savePreferences(value) ? "" : "Could not save this change. Try again."
  }
  function status(id) {
    var p = Providers.find(service.providers, id)
    if (!p) return "Not enabled"
    return Model.fresh(p, service.nowMs) ? "Ready" : Model.message(p, service.nowMs)
  }
  component Label: Text {
    textFormat: Text.PlainText
    color: root.ink
    font.family: "sans-serif"
    font.pixelSize: Style.space(13)
  }
  Column {
    width: parent.width
    spacing: Style.space(6)
    Label { text: "Settings"; font.pixelSize: Style.space(18); font.weight: Font.DemiBold }
    Label { width: parent.width; text: "Changes apply immediately."; color: root.dim; wrapMode: Text.WordWrap }
  }
  Repeater {
    model: root.orderKey ? root.orderKey.split(",") : []
    Rectangle {
      id: providerRow
      required property string modelData
      required property int index
      readonly property var meta: Providers.find(root.service.catalog, modelData)
      width: root.width
      height: providerContent.implicitHeight + Style.space(28)
      radius: Style.space(14)
      color: root.group
      Column {
        id: providerContent
        x: Style.space(14); y: x
        width: parent.width - x * 2
        spacing: Style.space(12)
        Row {
          width: parent.width
          spacing: Style.space(7)
          TintedIcon {
            width: Style.space(18); height: width
            anchors.verticalCenter: parent.verticalCenter
            iconSource: Qt.resolvedUrl("assets/" + providerRow.meta.icon)
            ink: root.dim
          }
          Label {
            width: parent.width - Style.space(87)
            anchors.verticalCenter: parent.verticalCenter
            text: providerRow.meta.name
            font.pixelSize: Style.space(15); font.weight: Font.DemiBold
          }
          PanelActionButton {
            size: Style.space(24)
            iconText: ""
            foreground: root.ink
            focusable: true
            enabled: providerRow.index > 0
            Accessible.name: "Move " + providerRow.meta.name + " up"
            onClicked: root.reorder(providerRow.modelData, -1)
          }
          PanelActionButton {
            size: Style.space(24)
            iconText: ""
            foreground: root.ink
            focusable: true
            enabled: providerRow.index < root.preferences.providerOrder.length - 1
            Accessible.name: "Move " + providerRow.meta.name + " down"
            onClicked: root.reorder(providerRow.modelData, 1)
          }
        }
        Label { width: parent.width; text: root.status(providerRow.modelData); color: root.dim; font.pixelSize: Style.space(12); wrapMode: Text.WordWrap }
        Rectangle {
          width: parent.width; height: Style.space(34)
          radius: height / 2
          color: root.track
          Row {
            anchors.fill: parent; anchors.margins: Style.space(3)
            Repeater {
              model: [{id: "bar", label: "Bar + panel"}, {id: "panel", label: "Panel only"}, {id: "off", label: "Off"}]
              PillButton {
                id: displayChoice
                required property var modelData
                width: parent.width / 3; height: parent.height
                text: modelData.label
                ink: root.ink
                surface: root.preferences.providers[providerRow.modelData].display === modelData.id ? root.surface : "transparent"
                hotSurface: root.group
                Accessible.role: Accessible.RadioButton
                Accessible.name: providerRow.meta.name + ": " + modelData.label
                Accessible.checked: root.preferences.providers[providerRow.modelData].display === modelData.id
                onClicked: root.display(providerRow.modelData, modelData.id)
              }
            }
          }
        }
      }
    }
  }
  AbstractButton {
    id: costsToggle
    width: parent.width; height: Math.max(costLabel.implicitHeight, costSwitch.implicitHeight)
    activeFocusOnTab: true
    hoverEnabled: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: "Show cost estimates"
    Accessible.checked: root.preferences.showCosts
    onClicked: root.setCosts(!root.preferences.showCosts)
    background: Rectangle { color: "transparent"; radius: Style.space(6); border.width: costsToggle.activeFocus ? 1 : 0; border.color: root.ink }
    contentItem: Item {
      Column {
        id: costLabel
        width: parent.width - costSwitch.width - Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)
        Label { text: "Show cost estimates"; font.weight: Font.DemiBold }
        Label { width: parent.width; text: "Today, Yesterday and 30 Days"; color: root.dim; font.pixelSize: Style.space(12); wrapMode: Text.WordWrap }
      }
      ToggleSwitch {
        id: costSwitch
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        interactive: false
        checked: root.preferences.showCosts
        foreground: root.ink
      }
    }
  }
  Label { width: parent.width; visible: root.error !== ""; text: root.error; wrapMode: Text.WordWrap }
  Row {
    anchors.right: parent.right
    spacing: Style.space(8)
    PillButton { text: "Done"; ink: root.ink; surface: root.group; hotSurface: root.track; onClicked: root.done() }
  }
}
