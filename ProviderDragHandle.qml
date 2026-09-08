import QtQuick
import qs.Commons

MouseArea {
  id: root
  required property var reorder
  required property Item providerItem
  required property string providerName
  objectName: "reorder-" + providerItem.providerId
  property color ink: Color.popups.text
  width: Style.space(24)
  height: Style.space(28)
  hoverEnabled: true
  preventStealing: true
  activeFocusOnTab: true
  cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
  Accessible.role: Accessible.Button
  Accessible.name: "Reorder " + providerName
  Accessible.description: "Drag to reorder. Up and Down move this provider. Escape cancels a drag."
  onActiveFocusChanged: reorder.keyboardFocus = activeFocus
  onPressed: function(mouse) {
    forceActiveFocus()
    reorder.begin(providerItem, mapToItem(reorder.container, mouse.x, mouse.y))
  }
  onPositionChanged: function(mouse) {
    if (pressed) reorder.update(mapToItem(reorder.container, mouse.x, mouse.y))
  }
  onReleased: reorder.finish()
  onCanceled: reorder.cancel()
  Keys.onEscapePressed: function(event) { reorder.cancel(); focus = false; event.accepted = true }
  Keys.onUpPressed: function(event) { reorder.shift(providerItem, -1); event.accepted = true }
  Keys.onDownPressed: function(event) { reorder.shift(providerItem, 1); event.accepted = true }
  Component.onDestruction: if (reorder.dragged === providerItem) reorder.cancel()
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: root.activeFocus ? 1 : 0
    border.color: root.ink
    radius: Style.cornerRadius
  }
  TintedIcon {
    x: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(16); height: width
    iconSource: Qt.resolvedUrl("assets/grip.svg")
    ink: root.ink
    opacity: root.containsMouse || root.pressed || root.activeFocus ? 1 : 0.55
  }
}
