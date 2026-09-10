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
const require = createRequire(import.meta.url)
const paletteModule = { exports: {} }
const paletteOutput = ts.transpileModule(
  readFileSync(new URL('../src/common/style/palette.ts', import.meta.url), 'utf8'),
  {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  },
).outputText
runInNewContext(`(function(module, exports) { ${paletteOutput}\n })`)(
  paletteModule,
  paletteModule.exports,
)
const module = { exports: {} }
runInNewContext(`(function(module, exports, require) { ${output}\n })`)(
  module,
  module.exports,
  id => (id.endsWith('/style/palette') ? paletteModule.exports : require(id)),
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

test('independent light and dark palettes follow appearance without overwriting either choice', () => {
  const model = SiteViewModel.fromData({}, SiteTheme.LIGHTEN)
  model.setLightPalette('rose-pine-dawn')
  model.setDarkPalette('rose-pine-moon')
  assert.equal(model.palette$.getSnapshot(), 'rose-pine-dawn')
  model.setDeviceTheme(SiteTheme.DARKEN)
  assert.equal(model.palette$.getSnapshot(), 'rose-pine-moon')
  assert.equal(model.lightPalette$.getSnapshot(), 'rose-pine-dawn')
  model.setThemePreference(SiteTheme.LIGHTEN)
  assert.equal(model.palette$.getSnapshot(), 'rose-pine-dawn')
  model.setDarkPalette('rose-pine')
  assert.equal(model.palette$.getSnapshot(), 'rose-pine-dawn')
  const restored = SiteViewModel.fromData(model.dump(), SiteTheme.DARKEN)
  assert.equal(restored.palette$.getSnapshot(), 'rose-pine-dawn')
  restored.setThemePreference('system')
  assert.equal(restored.palette$.getSnapshot(), 'rose-pine')
  model.dispose()
  restored.dispose()
})

test('legacy or invalid palette preferences fall back to mode-compatible Modern colors', () => {
  for (const data of [
    { theme: 'darken' },
    { lightPalette: 'rose-pine', darkPalette: 'rose-pine-dawn' },
    { lightPalette: 42, darkPalette: 'invalid' },
  ]) {
    const model = SiteViewModel.fromData(data)
    assert.equal(model.lightPalette$.getSnapshot(), 'vsc-light-modern')
    assert.equal(model.darkPalette$.getSnapshot(), 'vsc-dark-modern')
    model.dispose()
  }
})
