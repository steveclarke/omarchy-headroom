const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const api = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../Providers.js`, 'utf8'), api);
const raw = fs.readFileSync(`${__dirname}/../providers.json`, 'utf8');
const catalog = api.catalog(raw);
const plain = value => JSON.parse(JSON.stringify(value));

test('bundled catalog validates; malformed or duplicated entries fail closed', () => {
  assert.equal(catalog.length, 2);
  assert.deepEqual(plain(api.catalog('invalid')), []);
  const duplicate = JSON.parse(raw); duplicate.providers[1].id = 'claude';
  assert.deepEqual(plain(api.catalog(JSON.stringify(duplicate))), []);
  const unsafe = JSON.parse(raw); unsafe.providers[0].icon = '../private.svg';
  assert.deepEqual(plain(api.catalog(JSON.stringify(unsafe))), []);
});
test('defaults show both providers in the bar, sanitizing unknown preferences', () => {
  const settings = api.normalize(catalog, {providerOrder:['unknown', 'codex', 'codex'], providers:{codex:{display:'invalid'}}});
  assert.deepEqual(plain(settings.providerOrder), ['codex','claude']);
  assert.deepEqual(plain(api.selected(catalog, settings, true)), ['codex','claude']);
});
test('panel-only continues collection; off removes it from collection', () => {
  const settings = api.normalize(catalog, {providers:{claude:{display:'panel'},codex:{display:'off'}}});
  assert.deepEqual(plain(api.selected(catalog, settings, false)), ['claude']);
  assert.deepEqual(plain(api.selected(catalog, settings, true)), []);
  settings.providers.claude.display='off';
  assert.deepEqual(plain(api.selected(catalog, settings, false)), []);
});
test('settings persistence retains unrelated native widget options', () => {
  const original={id:'headroom',enabled:true,monitor:'primary',custom:{value:4}};
  const config={bar:{layout:{center:[null, "omarchy.clock", original]}}};
  const found=api.entry(config,'headroom');
  const saved=api.mergedEntry(found,api.normalize(catalog,{}));
  assert.equal(saved.monitor,'primary');
  assert.equal(saved.custom.value,4);
  assert.equal(original.providerOrder,undefined);
  assert.deepEqual(plain(api.entry({},'headroom')),{});
});

test('oversized order settings fall back to the bounded catalog', () => {
  const settings=api.normalize(catalog,{providerOrder:Array(1000).fill('codex')});
  assert.deepEqual(plain(settings.providerOrder),['claude','codex']);
});

test('legacy visibility migrates and disabled providers retain their top-bar choice', () => {
  for (const mode of ['bar','panel','off']) {
    const saved = api.normalize(catalog, {providers:{claude:{display:mode}}});
    assert.equal(saved.providers.claude.display, mode);
    assert.equal(saved.providers.claude.showInBar, mode !== 'panel');
    assert.deepEqual(plain(api.normalize(catalog, plain(saved))), plain(saved));
  }
  const saved = api.normalize(catalog, {providers:{claude:{display:'off',showInBar:false}}});
  assert.equal(api.normalize(catalog, plain(saved)).providers.claude.showInBar, false);
  assert.deepEqual(plain(api.selected(catalog, saved, false)), ['codex']);
});

test('drag moves an ID without swapping other providers or changing preferences', () => {
  const initial={providerOrder:['a','hidden','b','c'],providers:{a:{display:'panel'},hidden:{display:'off'}}};
  const next=plain(api.reordered(initial,'a','c',true));
  assert.deepEqual(next.providerOrder,['hidden','b','c','a']);
  assert.deepEqual(next.providers,initial.providers);
  assert.deepEqual(plain(api.reordered(next,'a','b',false)).providerOrder,['hidden','a','b','c']);
  assert.deepEqual(plain(api.reordered(initial,'unknown','a',false)),initial);
  assert.deepEqual(initial.providerOrder,['a','hidden','b','c']);
});

test('settings written by `omarchy bar set` arrive as strings', () => {
  // The CLI stores unquoted values as strings; the UI stores real types.
  const settings=api.normalize(catalog,{providers:{claude:{display:'off',showInBar:'false'}}});
  assert.equal(settings.providers.claude.showInBar,false);
  assert.equal(api.normalize(catalog,{providers:{claude:{display:'off',showInBar:'true'}}}).providers.claude.showInBar,true);
  assert.equal(api.normalize(catalog,{providers:{claude:{display:'off',showInBar:'maybe'}}}).providers.claude.showInBar,true);
});
