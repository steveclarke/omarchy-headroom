import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "Costs.js" as Costs
import "Providers.js" as Providers

// One service owns preferences and collection for every monitor.
Item {
  id: root
  visible: false
  property var shell: null
  property var manifest: null
  readonly property string pluginId: "io.github.steveclarke.headroom"
  readonly property var catalog: Providers.catalog(catalogFile.text())
  // The shell hands a plugin a one-time copy of the bar config and no
  // shellConfig, so the entry is seeded from that copy and then kept current by
  // the bar widget, whose `settings` the bar patches live.
  property var entry: ({})
  onShellChanged: if (shell && shell.barConfig) entry = Providers.entry({bar: shell.barConfig}, pluginId)
  readonly property var preferences: Providers.normalize(catalog, entry)
  readonly property var selectedIds: Providers.selected(catalog, preferences, false, false)
  readonly property var costIds: preferences.showCosts ? Providers.selected(catalog, preferences, false, true) : []
  readonly property var barProviders: providers.filter(function(p) { return root.preferences.providers[p.id] && root.preferences.providers[p.id].display === "bar" })
  property var providers: []
  property var costs: Costs.empty([])
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
  property bool initialized: false
  property string activeSelection: ""
  property string activeCostSelection: ""

  FileView {
    id: catalogFile
    path: decodeURIComponent(Qt.resolvedUrl("providers.json").toString().replace(/^file:\/\//, ""))
    blockLoading: true
  }

  function key(ids) { return ids.slice().sort().join(",") }
  function decorate(p) { return Object.assign({}, p, Providers.find(catalog, p.id)) }
  function emptyProvider(id) { return decorate(Model.empty(id, Providers.find(catalog, id).name)) }
  function ordered(records) {
    return selectedIds.map(function(id) { return root.decorate(Providers.find(records, id) || root.emptyProvider(id)) })
  }

  function configure() {
    var quotaKey = key(selectedIds), costKey = key(costIds)
    if (quotaKey !== activeSelection) {
      collector.cancel()
      lastAttemptAt = 0
      nextRefreshAt = selectedIds.length ? Date.now() : 0
      activeSelection = quotaKey
    }
    providers = ordered(providers)
    if (costKey !== activeCostSelection) {
      costCollector.cancel()
      costs = Costs.empty(costIds)
      lastCostAttemptAt = 0
      nextCostRefreshAt = costIds.length ? Date.now() : 0
      activeCostSelection = costKey
    }
    if (demoMode !== "") showDemo()
  }
  // Let derived selections settle before cancelling or scheduling workers.
  onPreferencesChanged: if (initialized) Qt.callLater(configure)

  function savePreferences(value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var normalized = Providers.normalize(catalog, value)
    if (JSON.stringify(normalized) === JSON.stringify(preferences)) return true
    // The native API replaces this entry's fields, so preserve other options.
    var merged = Providers.mergedEntry(entry, normalized)
    var saved = shell.updateEntryInline(pluginId, merged)
    if (saved) entry = merged
    return saved
  }

  function refresh() {
    if (demoMode !== "") { showDemo(); return }
    refreshCosts()
    var age = Date.now() - lastAttemptAt
    if (!selectedIds.length || collector.active || (age >= 0 && age < 20000)) return
    lastAttemptAt = Date.now()
    batchesStarted++
    collector.start()
  }
  function refreshCosts() {
    var age = Date.now() - lastCostAttemptAt
    if (!costIds.length || demoMode !== "" || costCollector.active || (age >= 0 && age < 20000)) return
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
  function showDemo() {
    providers = ordered(Model.demo(nowMs, demoMode))
    var sample = Costs.demo(nowMs, demoMode)
    costs = {observedAt: sample.observedAt, providers: costIds.map(function(id) { return Providers.find(sample.providers, id) || Costs.empty([id]).providers[0] })}
  }
  function preview(mode) {
    if (["", "normal", "stale", "empty"].indexOf(mode) < 0) return
    collector.cancel()
    costCollector.cancel()
    demoMode = mode
    nowMs = Date.now()
    if (mode === "") {
      providers = selectedIds.map(function(id) { return root.emptyProvider(id) })
      costs = Costs.empty(costIds)
      lastAttemptAt = 0; lastCostAttemptAt = 0
      nextRefreshAt = selectedIds.length ? nowMs : 0
      nextCostRefreshAt = costIds.length ? nowMs : 0
    } else showDemo()
  }

  Component.onCompleted: { initialized = true; configure(); startup.start() }
  Component.onDestruction: { collector.cancel(); costCollector.cancel() }
  Timer { id: startup; interval: 1000; onTriggered: root.refresh() }
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: {
      var current = Date.now()
      if (current < root.nowMs) {
        root.lastAttemptAt = 0; root.lastCostAttemptAt = 0
        root.nextRefreshAt = root.selectedIds.length ? current : 0
        root.nextCostRefreshAt = root.costIds.length ? current : 0
      }
      root.nowMs = current
      if (root.demoMode === "" && !collector.active && root.nextRefreshAt > 0 && current >= root.nextRefreshAt) root.refresh()
      if (root.demoMode === "" && !costCollector.active && root.nextCostRefreshAt > 0 && current >= root.nextCostRefreshAt) root.refreshCosts()
    }
  }
  CollectorProcess {
    id: costCollector
    costs: true
    providerIds: root.costIds
    onCompleted: function(doc) {
      if (root.key(requestIds) !== root.activeCostSelection || !root.costIds.length) return
      root.nextCostRefreshAt = Date.now() + 300000
      root.costs = doc
    }
    onFailed: { root.failCosts(); root.nextCostRefreshAt = root.costIds.length ? Date.now() + 300000 : 0 }
  }
  CollectorProcess {
    id: collector
    providerIds: root.selectedIds
    onCompleted: function(doc) {
      if (root.key(requestIds) !== root.activeSelection || !root.selectedIds.length) return
      root.nextRefreshAt = Date.now() + 300000
      var merged = doc.providers.map(function(p) { return Model.merge(Providers.find(root.providers, p.id), p) })
      root.providers = root.ordered(merged)
    }
    onFailed: { root.fail("Could not read usage · try refreshing"); root.nextRefreshAt = root.selectedIds.length ? Date.now() + 300000 : 0 }
  }
  IpcHandler {
    target: "headroom"
    function refresh(): void { root.refresh() }
    function preview(mode: string): void { root.preview(mode) }
    function period(index: int): void { if (index >= 0 && index <= 2) root.costPeriod = index }
    function status(): string {
      return JSON.stringify({refreshing: root.refreshing, costsRefreshing: root.costsRefreshing, demo: root.demoMode, batchesStarted: root.batchesStarted,
        costPeriod: root.costPeriod, preferences: root.preferences, costs: root.costs.providers.map(function(p) { return {id: p.id, state: p.state} }),
        providers: root.providers.map(function(p) { return {id: p.id, state: p.state, windows: p.windows.length, fresh: Model.fresh(p, root.nowMs)} })})
    }
  }
}
