const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const wire = vm.createContext({})
vm.runInContext(fs.readFileSync(`${__dirname}/../Wire.js`, 'utf8'), wire)
const parse = (raw, ids = ['claude', 'codex']) => wire.parse(raw, ids)
const report = () => ({schema: 1, observedAt: 100, providers: ['claude', 'codex'].map(id => ({id, message: '', state: 'fresh',
  name: id, plan: '', observedAt: 100, windows: [{id: 'weekly', title: 'Weekly', used: .5, resetAt: 1000, durationMs: 604800000}]}))})

test('rejects malformed boundaries atomically', () => {
  assert.equal(parse(JSON.stringify(report())).providers.length, 2)
  for (const mutate of [d => d.providers[1].id = 'claude', d => d.providers[0].windows = {},
    d => d.providers[0].message = 'x'.repeat(161), d => d.providers[0].message = '\u202eunsafe',
    d => d.providers[0].state = 'partial', d => d.providers[0].windows[0].used = -1]) {
    const doc = report(); mutate(doc)
    assert.throws(() => parse(JSON.stringify(doc)))
  }
})
test('bounds bytes and nesting before decoding', () => {
  assert.throws(() => parse(' '.repeat(131073)))
  assert.throws(() => parse('['.repeat(13) + '0' + ']'.repeat(13)))
  const doc = report(); doc.providers[0].message = '[{\\"quoted"}]'
  assert.equal(parse(JSON.stringify(doc)).providers.length, 2)
})
test('usage schema validates every window before use', () => {
  const doc = report()
  assert.equal(parse(JSON.stringify(doc)).providers.length, 2)
  doc.providers[1].windows[0].used = null
  assert.throws(() => parse(JSON.stringify(doc)))
})

test('reports must match the requested provider set, independent of order', () => {
  const doc = report(); doc.providers.reverse();
  assert.equal(parse(JSON.stringify(doc)).providers[0].id, 'codex');
  assert.throws(() => parse(JSON.stringify(doc), ['claude']));
  doc.providers = doc.providers.filter(p => p.id === 'codex');
  assert.equal(parse(JSON.stringify(doc), ['codex']).providers.length, 1);
  assert.throws(() => parse(JSON.stringify(doc), ['claude']));
  assert.throws(() => parse(JSON.stringify(doc), []));
  doc.providers = [];
  assert.equal(parse(JSON.stringify(doc), []).providers.length, 0);
});
