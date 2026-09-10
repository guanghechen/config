import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { runInNewContext } from 'node:vm'
import ts from 'typescript'

// Compile the enum in memory so this test runs on Node 24 without transform flags.
const source = readFileSync(new URL('../src/context/site/viewmodel.ts', import.meta.url), 'utf8')
const output = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText
const module = { exports: {} }
runInNewContext(`(function(module, exports, require) { ${output}\n })`)(
  module,
  module.exports,
  createRequire(import.meta.url),
)
const { SiteTheme, SiteViewModel } = module.exports

test('new users follow the device and persist the preference, not the resolved color', () => {
  const model = SiteViewModel.fromData({}, SiteTheme.DARKEN)
  assert.equal(model.themePreference$.getSnapshot(), 'system')
  assert.equal(model.theme$.getSnapshot(), SiteTheme.DARKEN)
  assert.equal(model.dump().theme, 'system')
  model.setDeviceTheme(SiteTheme.LIGHTEN)
  assert.equal(model.theme$.getSnapshot(), SiteTheme.LIGHTEN)
  assert.equal(model.dump().theme, 'system')
  model.dispose()
})

test('existing manual themes survive loading and ignore device changes', () => {
  for (const theme of [SiteTheme.LIGHTEN, SiteTheme.DARKEN]) {
    const model = SiteViewModel.fromData({ theme })
    model.setDeviceTheme(SiteTheme.DARKEN)
    model.setDeviceTheme(SiteTheme.LIGHTEN)
    assert.equal(model.theme$.getSnapshot(), theme)
    assert.equal(model.dump().theme, theme)
    model.dispose()
  }
})

test('switching back to follow device immediately uses its latest color', () => {
  const model = SiteViewModel.fromData({ theme: SiteTheme.LIGHTEN })
  model.setDeviceTheme(SiteTheme.DARKEN)
  model.setThemePreference('system')
  assert.equal(model.theme$.getSnapshot(), SiteTheme.DARKEN)
  model.setThemePreference(SiteTheme.LIGHTEN)
  assert.equal(model.theme$.getSnapshot(), SiteTheme.LIGHTEN)
  model.load({ theme: 'system' })
  assert.equal(model.theme$.getSnapshot(), SiteTheme.DARKEN)
  model.dispose()
})

test('invalid or missing persisted preferences fall back to a valid default', () => {
  for (const value of [undefined, null, {}, { theme: 'invalid' }, { theme: null }]) {
    const model = SiteViewModel.fromData(value, SiteTheme.DARKEN)
    assert.equal(model.themePreference$.getSnapshot(), 'system')
    assert.equal(model.theme$.getSnapshot(), SiteTheme.DARKEN)
    model.dispose()
  }
})
