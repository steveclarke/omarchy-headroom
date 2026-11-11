import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
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
  readonly property var selectedIds: Providers.selected(catalog, preferences, false)
  readonly property var barProviders: providers.filter(function(p) { return root.preferences.providers[p.id] && root.preferences.providers[p.id].display === "bar" })
  property var providers: []
  property double nowMs: Date.now()
  property bool refreshing: collector.active
  property string demoMode: ""
  property int batchesStarted: 0
  property double nextRefreshAt: 0
  property double lastAttemptAt: 0
  property bool initialized: false
  property string activeSelection: ""

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
    var quotaKey = key(selectedIds)
    if (quotaKey !== activeSelection) {
      collector.cancel()
      lastAttemptAt = 0
      nextRefreshAt = selectedIds.length ? Date.now() : 0
      activeSelection = quotaKey
    }
    providers = ordered(providers)
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
    var age = Date.now() - lastAttemptAt
    if (!selectedIds.length || collector.active || (age >= 0 && age < 20000)) return
    lastAttemptAt = Date.now()
    batchesStarted++
    collector.start()
  }
  function fail(message) {
    providers = providers.map(function(p) { return Object.assign({}, p, {state: "stale", message: message}) })
  }
  function showDemo() {
    providers = ordered(Model.demo(nowMs, demoMode))
  }
  function preview(mode) {
    if (["", "normal", "stale", "empty"].indexOf(mode) < 0) return
    collector.cancel()
    demoMode = mode
    nowMs = Date.now()
    if (mode === "") {
      providers = selectedIds.map(function(id) { return root.emptyProvider(id) })
      lastAttemptAt = 0
      nextRefreshAt = selectedIds.length ? nowMs : 0
    } else showDemo()
  }

  Component.onCompleted: { initialized = true; configure(); startup.start() }
  Component.onDestruction: collector.cancel()
  Timer { id: startup; interval: 1000; onTriggered: root.refresh() }
  Timer {
    interval: 1000; repeat: true; running: true
    onTriggered: {
      var current = Date.now()
      if (current < root.nowMs) {
        root.lastAttemptAt = 0
        root.nextRefreshAt = root.selectedIds.length ? current : 0
      }
      root.nowMs = current
      if (root.demoMode === "" && !collector.active && root.nextRefreshAt > 0 && current >= root.nextRefreshAt) root.refresh()
    }
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
    target: "io.github.steveclarke.headroom"
    function refresh(): void { root.refresh() }
    function preview(mode: string): void { root.preview(mode) }
    function status(): string {
      return JSON.stringify({refreshing: root.refreshing, demo: root.demoMode, batchesStarted: root.batchesStarted,
        preferences: root.preferences,
        providers: root.providers.map(function(p) { return {id: p.id, state: p.state, windows: p.windows.length, fresh: Model.fresh(p, root.nowMs)} })})
    }
  }
}
