import QtQuick
import Quickshell.Io
import "Wire.js" as Wire

// Own one refresh until exit, including cancellation. Bounded chunks keep
// diagnostics and malformed output out of the shared shell's model.
Item {
  id: root
  property bool costs: false
  property bool active: false
  property bool accepting: false
  property string buffer: ""
  property int errorSize: 0
  signal completed(var document)
  signal failed()

  function start() {
    if (active) return
    buffer = ""; errorSize = 0; accepting = true; active = true
    deadline.start()
    worker.running = true
  }
  function cancel() { accepting = false; buffer = ""; worker.running = false }
  function reject() {
    if (accepting) { cancel(); root.failed() }
  }
  Component.onDestruction: cancel()
  Timer {
    id: deadline; interval: 70000
    onTriggered: {
      root.reject()
      // A failure to launch has no exited signal. A running child must exit
      // before another refresh may start.
      if (!worker.running) root.active = false
    }
  }
  Process {
    id: worker
    command: ["/usr/bin/sh", "-c", root.costs
      ? "/usr/bin/python3 -I -S \"$1\" --parent \"$$\" --costs & wait"
      : "/usr/bin/python3 -I -S \"$1\" --parent \"$$\" & wait", "headroom",
      decodeURIComponent(Qt.resolvedUrl("bin/headroom-collect").toString().replace(/^file:\/\//, ""))]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (!root.accepting) return
        if (root.buffer.length + chunk.length > 131072) { root.reject(); return }
        root.buffer += chunk
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (!root.accepting) return
        root.errorSize += chunk.length
        if (root.errorSize > 8192) root.reject()
      }
    }
    onExited: function(exitCode) {
      deadline.stop()
      root.active = false
      if (!root.accepting) return
      root.accepting = false
      try {
        if (exitCode !== 0) throw new Error("exit")
        var doc = Wire.parse(root.buffer, root.costs)
        root.buffer = ""
        root.completed(doc)
      } catch (e) { root.buffer = ""; root.failed() }
    }
  }
}
