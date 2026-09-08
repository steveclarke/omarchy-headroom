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
  readonly property string orderKey: Providers.panelOrder(preferences).join(",")
  property string error: ""
  signal done()
  onVisibleChanged: if (!visible) orderDrag.cancel()
  onOrderKeyChanged: orderDrag.cancel()
  ProviderReorder {
    id: orderDrag
    container: root; repeater: providerRepeater
    onMoved: function(id, target, after) {
      root.reorderProvider(id, target, after)
    }
  }
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
  function reorderProvider(id, target, after) {
    apply(Providers.reordered(preferences, id, target, after))
    Qt.callLater(root.forceActiveFocus)
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
    id: providerRepeater
    model: root.orderKey ? root.orderKey.split(",") : []
    Item {
      id: providerRow
      required property string modelData
      required property int index
      readonly property string providerId: modelData
      z: orderDrag.dragged === providerRow && orderDrag.active ? 1 : 0
      opacity: orderDrag.active && orderDrag.dragged !== providerRow ? 0.45 : 1
      transform: Translate { y: orderDrag.dragged === providerRow ? orderDrag.offset : 0 }
      readonly property var meta: modelData === "cost" ? {name: "Cost"} : Providers.find(root.service.catalog, modelData)
      readonly property var preference: root.preferences.providers[modelData]
      width: root.width
      height: providerLayout.implicitHeight
      Rectangle { anchors.fill: parent; color: Color.popups.background; visible: orderDrag.dragged === providerRow && orderDrag.active }
      Column {
        id: providerLayout
        width: parent.width
        spacing: Style.spacing.sm
        Row {
          width: parent.width
          spacing: Style.spacing.sm
          ProviderDragHandle {
            id: grip
            anchors.verticalCenter: parent.verticalCenter
            reorder: orderDrag; providerItem: providerRow; providerName: providerRow.meta.name
            ink: root.dim
          }
          SwitchRow {
            width: parent.width - grip.width - parent.spacing
            label: providerRow.meta.name
            description: providerRow.modelData === "cost" ? "Today, Yesterday and 30 Days" : root.status(providerRow.modelData)
            checked: providerRow.modelData === "cost" ? root.preferences.showCosts : providerRow.preference.display !== "off"
            Accessible.name: "Enable " + providerRow.meta.name
            onClicked: providerRow.modelData === "cost" ? root.setCosts(!checked) : root.setProviderEnabled(providerRow.modelData, !checked)
          }
        }
        SwitchRow {
          visible: providerRow.modelData !== "cost"
          x: Style.space(24) + Style.spacing.sm
          width: parent.width - x
          label: "Show weekly usage in top bar"
          checked: !!providerRow.preference && providerRow.preference.showInBar
          enabled: !!providerRow.preference && providerRow.preference.display !== "off"
          Accessible.name: providerRow.meta.name + ": " + label
          onClicked: root.setShowInBar(providerRow.modelData, !checked)
        }
      }
    }
  }
  PanelSeparator { foreground: root.ink }
  Label { width: parent.width; visible: root.error !== ""; text: root.error; wrapMode: Text.WordWrap }
  Ui.Button {
    anchors.right: parent.right
    text: "Done"; foreground: root.ink; focusable: true; bordered: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    onClicked: root.done()
  }
}
