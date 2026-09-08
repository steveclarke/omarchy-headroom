import QtQuick
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "Providers.js" as Providers
import "Model.js" as Model

Column {
  id: root
  required property var service
  required property color ink
  required property color dim
  readonly property var preferences: service ? service.preferences : Providers.normalize([], {})
  // Changing a switch must not rebuild the focused provider controls.
  readonly property string orderKey: preferences.providerOrder.join(",")
  property string error: ""
  signal done()
  spacing: Style.spacing.panelGap
  Keys.onEscapePressed: function(event) { root.done(); event.accepted = true }

  function begin() { error = ""; forceActiveFocus() }
  function setProviderEnabled(id, value) {
    var next = JSON.parse(JSON.stringify(preferences)), provider = next.providers[id]
    provider.display = value ? (provider.showInBar ? "bar" : "panel") : "off"
    apply(next)
  }
  function setShowInBar(id, value) {
    var next = JSON.parse(JSON.stringify(preferences)), provider = next.providers[id]
    if (provider.display === "off") return
    provider.showInBar = value
    provider.display = value ? "bar" : "panel"
    apply(next)
  }
  function reorder(id, direction) {
    var next = JSON.parse(JSON.stringify(preferences)), index = next.providerOrder.indexOf(id), target = index + direction
    if (target < 0 || target >= next.providerOrder.length) return
    var other = next.providerOrder[target]
    next.providerOrder[target] = id; next.providerOrder[index] = other
    apply(next)
    Qt.callLater(function() { root.forceActiveFocus() })
  }
  function setCosts(value) { apply(Object.assign({}, preferences, {showCosts: value})) }
  function apply(value) {
    error = service && service.savePreferences(value) ? "" : "Could not save this change. Try again."
  }
  function status(id) {
    if (preferences.providers[id].display === "off") return "Not enabled"
    var p = Providers.find(service.providers, id)
    return p ? (Model.fresh(p, service.nowMs) ? "Ready" : Model.message(p, service.nowMs)) : "Waiting for usage"
  }
  component Label: Text {
    textFormat: Text.PlainText
    color: root.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
  component SwitchRow: Ui.Toggle {
    foreground: root.ink
    titleSize: Style.font.body
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
  }
  Column {
    width: parent.width
    spacing: Style.spacing.labelGap
    Label { text: "Settings"; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold }
    Label { width: parent.width; text: "Changes apply immediately."; color: root.dim; wrapMode: Text.WordWrap }
  }
  Repeater {
    model: root.orderKey ? root.orderKey.split(",") : []
    Column {
      id: providerRow
      required property string modelData
      required property int index
      readonly property var meta: Providers.find(root.service.catalog, modelData)
      readonly property var preference: root.preferences.providers[modelData]
      width: root.width
      spacing: Style.spacing.sm
      Row {
        width: parent.width
        spacing: Style.spacing.sm
        TintedIcon {
          width: Style.font.iconLarge; height: width
          anchors.verticalCenter: parent.verticalCenter
          iconSource: Qt.resolvedUrl("assets/" + providerRow.meta.icon)
          ink: root.dim
        }
        SwitchRow {
          width: parent.width - Style.font.iconLarge - up.width - down.width - parent.spacing * 3
          label: providerRow.meta.name
          description: root.status(providerRow.modelData)
          checked: providerRow.preference.display !== "off"
          Accessible.name: "Enable " + providerRow.meta.name
          onClicked: root.setProviderEnabled(providerRow.modelData, !checked)
        }
        PanelActionButton {
          id: up
          anchors.verticalCenter: parent.verticalCenter
          size: Style.space(24); iconText: ""; foreground: root.ink
          focusable: true; enabled: providerRow.index > 0
          Accessible.name: "Move " + providerRow.meta.name + " up"
          onClicked: root.reorder(providerRow.modelData, -1)
        }
        PanelActionButton {
          id: down
          anchors.verticalCenter: parent.verticalCenter
          size: Style.space(24); iconText: ""; foreground: root.ink
          focusable: true; enabled: providerRow.index < root.preferences.providerOrder.length - 1
          Accessible.name: "Move " + providerRow.meta.name + " down"
          onClicked: root.reorder(providerRow.modelData, 1)
        }
      }
      SwitchRow {
        x: Style.font.iconLarge + Style.spacing.sm
        width: parent.width - x
        label: "Show weekly usage in top bar"
        checked: providerRow.preference.showInBar
        enabled: providerRow.preference.display !== "off"
        Accessible.name: providerRow.meta.name + ": " + label
        onClicked: root.setShowInBar(providerRow.modelData, !checked)
      }
    }
  }
  PanelSeparator { foreground: root.ink }
  SwitchRow {
    width: parent.width
    label: "Show cost estimates"
    description: "Today, Yesterday and 30 Days"
    checked: root.preferences.showCosts
    onClicked: root.setCosts(!checked)
  }
  Label { width: parent.width; visible: root.error !== ""; text: root.error; wrapMode: Text.WordWrap }
  Ui.Button {
    anchors.right: parent.right
    text: "Done"; foreground: root.ink; focusable: true; bordered: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    onClicked: root.done()
  }
}
