const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const costs = vm.createContext({});
vm.runInContext(readFileSync(new URL('../Costs.js', `file://${__filename}`), 'utf8'), costs);
const now = new Date(2030, 0, 1, 12).getTime();

test('calendar periods include today plus 29 previous days across a year boundary', () => {
  const doc = costs.demo(now, 'normal');
  doc.providers[0].daily[costs.dayKey(now, -29)] = 5;
  doc.providers[0].daily[costs.dayKey(now, -30)] = 9999;
  assert.equal(costs.amount(doc, 0, 0, now), 84.2);
  assert.equal(costs.amount(doc, 0, 1, now), 62.1);
  assert.ok(Math.abs(costs.amount(doc, 0, 2, now) - 892.1) < 1e-9);
  assert.equal(costs.dayKey(now, -1), '2029-12-31');
});

test('a missing or unpriced provider cannot become a zero or a complete total', () => {
  const doc = costs.demo(now, 'normal');
  doc.providers[1].state = 'partial';
  assert.equal(costs.total(doc, 0, now), null);
  assert.equal(costs.amount(doc, 1, 0, now), null);
  assert.equal(costs.amount(doc, 0, 0, now), 84.2);
  assert.equal(costs.amount(costs.empty(), 0, 0, now), null);
});

test('fresh empty daily data is zero; yesterday data cannot impersonate today after midnight', () => {
  const doc = costs.demo(now, 'normal');
  doc.providers[0].daily = {};
  assert.equal(costs.amount(doc, 0, 0, now), 0);
  assert.equal(costs.amount(doc, 0, 0, now + 600001), null);
  const midnight = new Date(2030, 0, 2).getTime();
  doc.observedAt = midnight - 1000;
  assert.equal(costs.amount(doc, 0, 0, midnight + 1000), null);
});

test('local calendar stepping survives a DST transition without dropping a day', () => {
  const previous = process.env.TZ;
  process.env.TZ = 'America/St_Johns';
  try {
    const after = new Date(2030, 2, 11, 0, 15).getTime();
    assert.equal(costs.dayKey(after, -1), '2030-03-10');
    assert.equal(costs.dayKey(after, -2), '2030-03-09');
  } finally {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  }
});

test('future observations fail closed after a clock rollback', () => {
  const now = new Date(2030, 0, 1, 10).getTime()
  const doc = costs.demo(now + 7200000, 'normal')
  assert.equal(costs.amount(doc, 0, 0, now), null)
})
