// Pure quota arithmetic. Times are epoch milliseconds; usage is a fraction.
// Observation time stays fixed between refreshes. The display clock only
// advances countdowns and invalidates stale or expired observations.
var MAX_AGE_MS = 10 * 60 * 1000

function finite(value) { return typeof value === "number" && isFinite(value) }
function clamp(value, lo, hi) { return Math.max(lo, Math.min(hi, value)) }

function evaluate(window, observedAt, now, fresh) {
  if (!window || !fresh || !finite(observedAt) || !finite(now)
      || observedAt > now + 5000 || now - observedAt > MAX_AGE_MS) return null
  var u = window.used
  var duration = window.durationMs
  var reset = window.resetAt
  if (!finite(u) || u < 0 || !finite(reset) || reset <= now) return null
  if (u >= 1) return {status: "exhausted", projected: null, spare: 0, exhaustionAt: null, marker: null}
  if (!finite(duration) || duration <= 0 || u === 0) return null
  var elapsed = observedAt - (reset - duration)
  if (elapsed < Math.max(60000, duration * 0.01) || elapsed >= duration) return null
  var rate = u / elapsed
  var projected = rate * duration
  var spare = 1 - projected
  return {
    status: spare >= 0.1 - 1e-10 ? "calm" : spare > 1e-10 ? "caution" : "urgent",
    projected: projected,
    spare: spare,
    exhaustionAt: projected > 1 + 1e-10 ? observedAt + (1 - u) / rate : null,
    marker: clamp((now - (reset - duration)) / duration, 0, 1)
  }
}

function duration(ms) {
  if (!finite(ms) || ms <= 0) return "now"
  var m = Math.max(1, Math.ceil(ms / 60000))
  var h = Math.floor(m / 60)
  var d = Math.floor(h / 24)
  if (d) return d + "d " + (h % 24) + "h"
  if (h) return h + "h " + (m % 60) + "m"
  return m + "m"
}

function summary(result, now) {
  if (!result) return ""
  if (result.status === "exhausted") return "Limit reached"
  if (result.exhaustionAt !== null)
    return result.exhaustionAt > now ? "Limit in " + duration(result.exhaustionAt - now) : "Limit expected now"
  if (result.status === "urgent") return "No buffer at reset"
  var pct = result.spare * 100
  var value = pct < 1 ? "<1%" : "~" + Math.round(pct) + "%"
  return value + (result.status === "caution" ? " spare" : " left at reset")
}

function tooltip(result) {
  if (!result) return "A forecast needs fresh usage and a known reset window."
  if (result.status === "exhausted") return "The reported allowance has been used."
  var projection = result.projected > 1
    ? "~" + Math.round((result.projected - 1) * 100) + "% over the allowance at reset."
    : "~" + Math.round(result.projected * 100) + "% used at reset."
  return projection + " Based on average use since this window began, not recent activity or additional charges."
}
