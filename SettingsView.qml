import QtQuick
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "Providers.js" as Providers

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
  component Label: Text {
    textFormat: Text.PlainText
    color: root.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
  readonly property real controlWidth: Style.space(76)
  component SwitchCell: MouseArea {
    id: cell
    property bool checked: false
    required property string accessibleName
    signal toggled()
    width: root.controlWidth; height: Style.space(44)
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checked: checked
    Accessible.onToggleAction: cell.toggled()
    onClicked: toggled()
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    ToggleSwitch {
      anchors.centerIn: parent
      checked: cell.checked
      interactive: false
      cursorRing: true
      hasCursor: cell.containsMouse || cell.activeFocus
      foreground: root.ink
      trackHeight: Style.space(18)
    }
  }
  Label { text: "Settings"; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold }
  Row {
    width: parent.width
    Item { width: parent.width - 2 * root.controlWidth; height: 1 }
    Label { width: root.controlWidth; text: "Enabled"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.pixelSize: Style.font.bodySmall }
    Label { width: root.controlWidth; text: "Top bar"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.pixelSize: Style.font.bodySmall }
  }
  Repeater {
    id: providerRepeater
    model: root.orderKey ? root.orderKey.split(",") : []
    Item {
      id: providerRow
      required property string modelData
      readonly property string providerId: modelData
      readonly property var meta: modelData === "cost" ? {name: "Cost"} : Providers.find(root.service.catalog, modelData)
      readonly property var preference: root.preferences.providers[modelData]
      width: root.width
      height: Style.space(48)
      z: orderDrag.dragged === providerRow && orderDrag.active ? 1 : 0
      opacity: orderDrag.active && orderDrag.dragged !== providerRow ? 0.45 : 1
      transform: Translate { y: orderDrag.dragged === providerRow ? orderDrag.offset : 0 }
      Rectangle { anchors.fill: parent; color: Color.popups.background; visible: orderDrag.dragged === providerRow && orderDrag.active }
      Row {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        Item {
          width: parent.width - 2 * root.controlWidth
          height: Style.space(44)
          ProviderDragHandle {
            id: grip
            anchors.verticalCenter: parent.verticalCenter
            reorder: orderDrag; providerItem: providerRow; providerName: providerRow.meta.name
            ink: root.dim
          }
          Label {
            anchors.left: grip.right; anchors.leftMargin: Style.spacing.sm
            anchors.right: parent.right; anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: providerRow.meta.name
            elide: Text.ElideRight
          }
        }
        SwitchCell {
          objectName: "enabled-" + providerRow.providerId
          accessibleName: "Enable " + providerRow.meta.name
          checked: providerRow.modelData === "cost" ? root.preferences.showCosts : providerRow.preference.display !== "off"
          onToggled: providerRow.modelData === "cost" ? root.setCosts(!checked) : root.setProviderEnabled(providerRow.modelData, !checked)
        }
        Item {
          width: root.controlWidth; height: Style.space(44)
          SwitchCell {
            visible: providerRow.modelData !== "cost"
            objectName: "topbar-" + providerRow.providerId
            accessibleName: providerRow.meta.name + " in top bar"
            checked: !!providerRow.preference && providerRow.preference.showInBar
            enabled: !!providerRow.preference && providerRow.preference.display !== "off"
            onToggled: root.setShowInBar(providerRow.modelData, !checked)
          }
          Label {
            visible: providerRow.modelData === "cost"
            anchors.centerIn: parent; text: "—"; color: root.dim
          }
        }
      }
      PanelSeparator { anchors.bottom: parent.bottom; foreground: root.ink }
    }
  }
  Label {
    width: parent.width
    text: "Drag rows to reorder.\nTop bar shows weekly allowance remaining."
    color: root.dim; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
  }
  Label {
    width: parent.width
    text: "Disabling a provider stops collection and hides it. Its top-bar choice is kept."
    color: root.dim; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
  }
  Label { width: parent.width; visible: root.error !== ""; text: root.error; wrapMode: Text.WordWrap }
  Row {
    width: parent.width
    Label {
      width: parent.width - doneButton.width - Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      text: "Changes apply immediately."
      color: root.dim; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
    }
    Ui.Button {
      id: doneButton
      text: "Done"; foreground: root.ink; focusable: true; bordered: true
      Accessible.role: Accessible.Button
      Accessible.name: text
      onClicked: root.done()
    }
  }
}
