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
  property bool costsRefreshing: costCollector.active
  property double nextCostRefreshAt: 0
  property double lastCostAttemptAt: 0
  property int costPeriod: 0
  property double nowMs: Date.now()
  property bool refreshing: collector.active
  property string demoMode: ""
  property int batchesStarted: 0
  property double nextRefreshAt: 0
  property double lastAttemptAt: 0

  function refresh() {
    if (demoMode !== "") { providers = Model.demo(Date.now(), demoMode); costs = Costs.demo(Date.now(), demoMode); return }
    refreshCosts()
    // Coalesce calls from both bars and repeated clicks. Native Claude also
    // absorbs probes inside 15 seconds; don't mislabel that reuse as new data.
    var age = Date.now() - lastAttemptAt
    if (collector.active || (age >= 0 && age < 20000)) return
    lastAttemptAt = Date.now()
    batchesStarted++
    collector.start()
  }

  function refreshCosts() {
    var age = Date.now() - lastCostAttemptAt
    if (demoMode !== "" || costCollector.active || (age >= 0 && age < 20000)) return
    lastCostAttemptAt = Date.now()
    costCollector.start()
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
    collector.cancel()
    costCollector.cancel()
    demoMode = mode
    nextRefreshAt = Date.now(); nextCostRefreshAt = Date.now()
    nowMs = Date.now()
    if (mode === "") { providers = [Model.empty("claude"), Model.empty("codex")]; costs = Costs.empty(); lastAttemptAt = 0; lastCostAttemptAt = 0; refresh() }
    else { providers = Model.demo(nowMs, mode); costs = Costs.demo(nowMs, mode) }
  }

  Component.onCompleted: startup.start()
  Component.onDestruction: { collector.cancel(); costCollector.cancel() }
  Timer { id: startup; interval: 1000; onTriggered: root.refresh() }
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: {
      var current = Date.now()
      if (current < root.nowMs) {
        root.lastAttemptAt = 0; root.lastCostAttemptAt = 0
        root.nextRefreshAt = current; root.nextCostRefreshAt = current
      }
      root.nowMs = current
      if (root.demoMode === "" && !collector.active && root.nextRefreshAt > 0 && root.nowMs >= root.nextRefreshAt) root.refresh()
      if (root.demoMode === "" && !costCollector.active && root.nextCostRefreshAt > 0 && root.nowMs >= root.nextCostRefreshAt) root.refreshCosts()
    }
  }
  CollectorProcess {
    id: costCollector
    costs: true
    onCompleted: function(doc) {
      root.nextCostRefreshAt = Date.now() + 300000
      root.costs = doc
    }
    onFailed: { root.failCosts(); root.nextCostRefreshAt = Date.now() + 300000 }
  }
  CollectorProcess {
    id: collector
    onCompleted: function(doc) {
      root.nextRefreshAt = Date.now() + 300000
      root.providers = doc.providers.map(function(p, i) { return Model.merge(root.providers[i], p) })
    }
    onFailed: { root.fail("Could not read usage · try refreshing"); root.nextRefreshAt = Date.now() + 300000 }
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
