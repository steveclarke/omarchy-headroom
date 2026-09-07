const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const wire = vm.createContext({})
vm.runInContext(fs.readFileSync(`${__dirname}/../Wire.js`, 'utf8'), wire)
const report = () => ({schema: 1, observedAt: 100, providers: ['claude', 'codex'].map(id => ({id, message: '', state: 'fresh', daily: {'2030-01-01': 2}}))})

test('accepts complete costs and rejects malformed boundaries atomically', () => {
  assert.equal(wire.parse(JSON.stringify(report()), true).providers.length, 2)
  for (const mutate of [d => d.providers.reverse(), d => d.providers[0].daily = [],
    d => d.providers[0].daily.constructor = 10, d => d.providers[0].daily['2030-01-01'] = '2',
    d => d.providers[0].message = 'x'.repeat(161), d => d.providers[0].message = '\u202eunsafe',
    d => d.providers[0].daily['2030-01-01'] = -1]) {
    const doc = report(); mutate(doc)
    assert.throws(() => wire.parse(JSON.stringify(doc), true))
  }
})
test('bounds bytes and nesting before decoding', () => {
  assert.throws(() => wire.parse(' '.repeat(131073), true))
  assert.throws(() => wire.parse('['.repeat(13) + '0' + ']'.repeat(13), true))
  const doc = report(); doc.providers[0].message = '[{\\"quoted"}]'
  assert.equal(wire.parse(JSON.stringify(doc), true).providers.length, 2)
})
test('usage schema validates every window before use', () => {
  const doc = report()
  doc.providers.forEach(p => Object.assign(p, {name:p.id, plan:'', observedAt:100,
    windows:[{id:'weekly', title:'Weekly', used:.5, resetAt:1000, durationMs:604800000}]}))
  assert.equal(wire.parse(JSON.stringify(doc), false).providers.length, 2)
  doc.providers[1].windows[0].used = null
  assert.throws(() => wire.parse(JSON.stringify(doc), false))
})
