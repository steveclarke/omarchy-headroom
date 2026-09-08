import QtQuick
import qs.Commons

// One drag session per list. Persist only after release, never while delegates move.
QtObject {
  id: root
  required property var repeater
  required property Item container
  property var dragged: null
  property string targetId: ""
  property bool after: false
  property real offset: 0
  property real startY: 0
  property bool active: false
  property bool keyboardFocus: false
  signal moved(string providerId, string targetId, bool after)
  readonly property real dropY: {
    for (var i = 0; i < repeater.count; i++) {
      var item = repeater.itemAt(i)
      if (item && item.providerId === targetId) return item.y + (after ? item.height : 0)
    }
    return 0
  }
  // Zero size keeps this overlay out of the Column's layout.
  readonly property Item indicator: Item {
    parent: root.container
    width: 0; height: 0; z: 5
    Rectangle {
      width: root.container.width; height: Style.space(2)
      y: root.dropY
      visible: root.active && root.targetId !== ""
      color: Color.accent
    }
  }

  function begin(item, point) {
    cancel()
    dragged = item
    startY = point.y
  }
  function update(point) {
    if (!dragged) return
    var delta = point.y - startY
    if (!active && Math.abs(delta) < Style.space(6)) return
    active = true
    offset = delta
    targetId = ""
    if (point.x < 0 || point.x > container.width || point.y < 0 || point.y > container.height) return
    var center = dragged.y + dragged.height / 2 + offset
    for (var i = 0; i < repeater.count; i++) {
      var candidate = repeater.itemAt(i)
      if (candidate === dragged) continue
      var candidateCenter = candidate.y + candidate.height / 2
      if (offset > 0 && candidate.y > dragged.y && center >= candidateCenter) {
        targetId = candidate.providerId; after = true
      } else if (offset < 0 && candidate.y < dragged.y && center <= candidateCenter) {
        targetId = candidate.providerId; after = false
        break
      }
    }
  }
  function finish() {
    var id = dragged ? dragged.providerId : "", target = targetId, trailing = after
    cancel()
    if (id && target) Qt.callLater(function() { root.moved(id, target, trailing) })
  }
  function shift(item, direction) {
    var index = -1
    for (var i = 0; i < repeater.count; i++) if (repeater.itemAt(i) === item) index = i
    var next = index + direction
    if (index >= 0 && next >= 0 && next < repeater.count)
      moved(item.providerId, repeater.itemAt(next).providerId, direction > 0)
  }
  function cancel() { dragged = null; active = false; offset = 0; targetId = "" }
}
