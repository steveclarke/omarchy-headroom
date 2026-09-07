import QtQuick
import Qt5Compat.GraphicalEffects

Item {
  id: root
  required property string provider
  required property color ink
  Image {
    id: mark
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/" + root.provider + ".svg")
    sourceSize: Qt.size(width * 2, height * 2)
    visible: false
  }
  ColorOverlay { anchors.fill: parent; source: mark; color: root.ink }
}
