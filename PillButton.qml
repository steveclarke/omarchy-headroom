import QtQuick
import QtQuick.Controls
import qs.Commons

AbstractButton {
  id: root
  property string iconText: ""
  property color ink: Color.popups.text
  property color surface: Color.popups.background
  property color hotSurface: Color.accent
  implicitWidth: Math.max(Style.space(64), content.implicitWidth + Style.space(24))
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
  contentItem: Item {
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(6)
      opacity: root.enabled ? 1 : 0.5
      Text {
        visible: root.iconText !== ""
        width: Style.space(14); height: width
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.iconText
        color: root.ink
        font.family: Style.font.family
        font.pixelSize: Style.space(14)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Accessible.ignored: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.text
        color: root.ink
        font.family: "sans-serif"
        font.pixelSize: Style.space(12)
        font.weight: Font.DemiBold
      }
    }
  }
}
