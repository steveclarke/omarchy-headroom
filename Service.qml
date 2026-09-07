import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "Costs.js" as Costs

// The shell creates one service for this plugin, regardless of monitor count.
Item {
  id: root
  visible: false
  property var shell: null
  property var manifest: null
  property var providers: [Model.empty("claude"), Model.empty("codex")]
  property var costs: Costs.empty()
  property bool costsRefreshing: costCollector.running
  property double nextCostRefreshAt: 0
  property double lastCostAttemptAt: 0
  property int costPeriod: 0
  property double nowMs: Date.now()
  property bool refreshing: collector.running
  property string demoMode: ""
  property int batchesStarted: 0
  property double nextRefreshAt: 0
  property double lastAttemptAt: 0

  function refresh() {
    if (demoMode !== "") { providers = Model.demo(Date.now(), demoMode); costs = Costs.demo(Date.now(), demoMode); return }
    refreshCosts()
    // Coalesce calls from both bars and repeated clicks. Native Claude also
    // absorbs probes inside 15 seconds; don't mislabel that reuse as new data.
    if (collector.running || Date.now() - lastAttemptAt < 20000) return
    lastAttemptAt = Date.now()
    batchesStarted++
    collector.running = true
  }

  function refreshCosts() {
    if (demoMode !== "" || costCollector.running || Date.now() - lastCostAttemptAt < 20000) return
    lastCostAttemptAt = Date.now()
    costCollector.running = true
  }

  function failCosts() {
    costs = {observedAt: costs.observedAt, providers: costs.providers.map(function(p) {
      return Object.assign({}, p, {state: "stale", message: "Costs unavailable · refresh to retry"})
    })}
  }

  function fail(message) {
    providers = providers.map(function(p) { return Object.assign({}, p, {state: "stale", message: message}) })
  }

  function preview(mode) {
    if (["", "normal", "stale", "empty"].indexOf(mode) < 0) return
    if (collector.running) collector.running = false
    if (costCollector.running) costCollector.running = false
    demoMode = mode
    nowMs = Date.now()
    if (mode === "") { providers = [Model.empty("claude"), Model.empty("codex")]; costs = Costs.empty(); lastAttemptAt = 0; lastCostAttemptAt = 0; refresh() }
    else { providers = Model.demo(nowMs, mode); costs = Costs.demo(nowMs, mode) }
  }

  Component.onCompleted: startup.start()
  Component.onDestruction: { collector.running = false; costCollector.running = false }
  Timer { id: startup; interval: 1000; onTriggered: root.refresh() }
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: {
      root.nowMs = Date.now()
      if (root.demoMode === "" && !collector.running && root.nextRefreshAt > 0 && root.nowMs >= root.nextRefreshAt) root.refresh()
      if (root.demoMode === "" && !costCollector.running && root.nextCostRefreshAt > 0 && root.nowMs >= root.nextCostRefreshAt) root.refreshCosts()
    }
  }
  Timer {
    interval: 70000; running: costCollector.running
    onTriggered: { costCollector.running = false; root.failCosts(); root.nextCostRefreshAt = Date.now() + 300000 }
  }
  Process {
    id: costCollector
    command: ["sh", "-c", "python3 \"$1\" --parent \"$$\" --costs & wait", "headroom-costs",
      Qt.resolvedUrl("bin/headroom-collect").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector { id: costOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (root.demoMode !== "") return
      root.nextCostRefreshAt = Date.now() + 300000
      try {
        var doc = JSON.parse(costOutput.text)
        if (exitCode !== 0 || doc.schema !== 1 || !Array.isArray(doc.providers) || doc.providers.length !== 2) throw new Error("invalid")
        root.costs = doc
      } catch (e) { root.failCosts() }
    }
  }
  Timer {
    interval: 70000; running: collector.running
    onTriggered: { collector.running = false; root.fail("Usage check timed out · try refreshing"); root.nextRefreshAt = Date.now() + 300000 }
  }
  Process {
    id: collector
    // Quickshell kills its direct child on destruction. Keep the collector
    // separate so it can observe launcher death and stop its process groups.
    command: ["sh", "-c", "python3 \"$1\" --parent \"$$\" & wait", "headroom",
      Qt.resolvedUrl("bin/headroom-collect").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (root.demoMode !== "") return
      root.nextRefreshAt = Date.now() + 300000
      try {
        var doc = JSON.parse(output.text)
        if (exitCode !== 0 || doc.schema !== 1 || !Array.isArray(doc.providers) || doc.providers.length !== 2) throw new Error("invalid")
        root.providers = doc.providers.map(function(p, i) { return Model.merge(root.providers[i], p) })
      } catch (e) { root.fail("Could not read usage · try refreshing") }
    }
  }
  IpcHandler {
    target: "headroom"
    function refresh(): void { root.refresh() }
    function preview(mode: string): void { root.preview(mode) }
    function period(index: int): void { if (index >= 0 && index <= 2) root.costPeriod = index }
    function status(): string {
      return JSON.stringify({refreshing: root.refreshing, costsRefreshing: root.costsRefreshing, demo: root.demoMode, batchesStarted: root.batchesStarted,
        costPeriod: root.costPeriod, costs: root.costs.providers.map(function(p) { return {id: p.id, state: p.state} }),
        providers: root.providers.map(function(p) { return {id: p.id, state: p.state, windows: p.windows.length, fresh: Model.fresh(p, root.nowMs)} })})
    }
  }
}
