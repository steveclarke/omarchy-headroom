// Shared selection rules. The catalog is bundled; preferences contain only IDs.
function find(items, id) {
  for (var i = 0; i < items.length; i++) if (items[i] && items[i].id === id) return items[i]
  return null
}

function catalog(raw) {
  try {
    var items = JSON.parse(raw).providers, seen = []
    if (!Array.isArray(items) || !items.length || items.length > 20) return []
    for (var i = 0; i < items.length; i++) {
      var p = items[i]
      if (!p || typeof p.id !== "string" || !/^[a-z][a-z0-9-]{0,39}$/.test(p.id)
          || seen.indexOf(p.id) >= 0 || typeof p.name !== "string" || typeof p.shortName !== "string"
          || typeof p.icon !== "string" || !/^[a-z0-9-]+\.svg$/.test(p.icon)
          || typeof p.headline !== "string" || !Array.isArray(p.warningWindows)) return []
      seen.push(p.id)
    }
    return items
  } catch (e) { return [] }
}

function entry(config, id) {
  var layout = config && config.bar && config.bar.layout ? config.bar.layout : {}
  var groups = [layout.left, layout.center, layout.right, config ? config.plugins : []]
  for (var i = 0; i < groups.length; i++) {
    var match = find(Array.isArray(groups[i]) ? groups[i] : [], id)
    if (match) return match
  }
  return {}
}

function normalize(items, raw) {
  raw = raw || {}
  var order = [], modes = {}, requested = Array.isArray(raw.providerOrder) && raw.providerOrder.length <= 20 ? raw.providerOrder : []
  requested.concat(items.map(function(p) { return p.id })).forEach(function(id) {
    if (find(items, id) && order.indexOf(id) < 0) order.push(id)
  })
  order.forEach(function(id) {
    var p = raw.providers && raw.providers[id]
    var mode = p && p.display
    mode = ["off", "panel", "bar"].indexOf(mode) >= 0 ? mode : "bar"
    // Retain the top-bar choice while disabled; legacy display values still work.
    modes[id] = {display: mode, showInBar: mode === "off" ? p.showInBar !== false : mode === "bar"}
  })
  return {providerOrder: order, providers: modes, showCosts: raw.showCosts !== false}
}

function selected(items, preferences, barOnly, costsOnly) {
  return preferences.providerOrder.filter(function(id) {
    var mode = preferences.providers[id].display, p = find(items, id)
    return p && mode !== "off" && (!barOnly || mode === "bar") && (!costsOnly || p.costs === true)
  })
}

function mergedEntry(existing, preferences) {
  return Object.assign({}, existing, preferences)
}
