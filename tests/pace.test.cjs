const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const pace = vm.createContext({});
vm.runInContext(readFileSync(new URL('../Pace.js', `file://${__filename}`), 'utf8'), pace);
const model = vm.createContext({});
vm.runInContext(readFileSync(new URL('../Model.js', `file://${__filename}`), 'utf8'), model);
const hour = 3600000, now = 1900000000000;
const window = (used, elapsed = hour) => ({used, durationMs: 5 * hour, resetAt: now + 5 * hour - elapsed});
test('40% in an hour projects 90 minutes to exhaustion', () => {
  const result = pace.evaluate(window(.4), now, now, true);
  assert.equal(result.status, 'urgent');
  assert.equal(result.projected, 2);
  assert.equal(result.exhaustionAt, now + 1.5 * hour);
});
test('20% after two hours leaves half the allowance at reset', () => {
  const result = pace.evaluate(window(.2, 2 * hour), now, now, true);
  assert.equal(result.status, 'calm');
  assert.equal(result.spare, .5);
});
test('countdown ticks cannot change the sampled burn rate', () => {
  const a = pace.evaluate(window(.4), now, now, true);
  const b = pace.evaluate(window(.4), now, now + 60000, true);
  assert.equal(a.exhaustionAt, b.exhaustionAt);
  assert.equal(a.projected, b.projected);
  assert.notEqual(pace.summary(a, now), pace.summary(b, now + 60000));
});
test('no predictions from zero, early, unknown, stale, future, or invalid input', () => {
  for (const w of [window(0), window(.1, 1000), {...window(.4), durationMs: 0}, window(NaN), window(null)])
    assert.equal(pace.evaluate(w, now, now, true), null);
  assert.equal(pace.evaluate(window(.4), now, now, false), null);
  assert.equal(pace.evaluate(window(.4), now, now + 600001, true), null);
  assert.equal(pace.evaluate(window(.4), now + 10000, now, true), null);
  assert.equal(pace.evaluate({...window(.4), resetAt: now}, now, now, true), null);
});
test('boundaries distinguish caution, no buffer and exhausted', () => {
  assert.equal(pace.evaluate(window(.18), now, now, true).status, 'calm');
  assert.equal(pace.evaluate(window(.19), now, now, true).status, 'caution');
  const exact = pace.evaluate(window(.2), now, now, true);
  assert.equal(exact.status, 'urgent');
  assert.equal(exact.exhaustionAt, null);
  assert.equal(pace.evaluate(window(1), now, now, true).status, 'exhausted');
  assert.match(pace.summary(pace.evaluate(window(.199), now, now, true), now), /<1% spare/);
});
test('failed refresh keeps values but removes freshness', () => {
  const old = {state:'fresh', windows:[window(.4)], observedAt:now, plan:'Pro'};
  const result = model.merge(old, {state:'unavailable', windows:[], observedAt:0});
  assert.equal(result.windows.length, 1);
  assert.equal(model.fresh(result, now), false);
});
test('missing and reset values never read as a full allowance', () => {
  assert.equal(model.percentage(null, now), '—');
  assert.equal(model.percentage({...window(.4), resetAt:now}, now), '—');
});
