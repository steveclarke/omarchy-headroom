import QtQuick
import QtQuick.Controls
import qs.Commons

AbstractButton {
  id: root
  property color ink: Color.popups.text
  property color surface: Color.popups.background
  property color hotSurface: Color.accent
  implicitWidth: Math.max(Style.space(64), label.implicitWidth + Style.space(24))
  implicitHeight: Style.space(30)
  hoverEnabled: true
  activeFocusOnTab: true
  Accessible.name: text
  background: Rectangle {
    radius: height / 2
    color: root.hovered || root.down ? root.hotSurface : root.surface
    border.width: root.activeFocus ? 1 : 0
    border.color: root.ink
  }
  contentItem: Text {
    id: label
    textFormat: Text.PlainText
    text: root.text
    color: root.ink
    opacity: root.enabled ? 1 : 0.5
    font.family: "sans-serif"
    font.pixelSize: Style.space(12)
    font.weight: Font.DemiBold
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
