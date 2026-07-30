import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import test from 'node:test'

import {
  CONFIG_DIVIDER,
  renderConfig,
  renderTheme,
  syncConfig,
  writeFileAtomically,
} from './sync.mjs'

const THEME = {
  name: 'vsc-dark-modern',
  custom: {
    panel_bg: '#1F1F1F',
    surface_dim: '#313131',
    surface0: '#3C3C3C',
    surface1: '#454545',
    overlay0: '#6E7681',
    overlay1: '#868686',
    text: '#CCCCCC',
    subtext0: '#9D9D9D',
    accent: '#F5A9B8',
    mauve: '#C586C0',
    green: '#2EA043',
    yellow: '#DCDCAA',
    red: '#F85149',
    blue: '#0078D4',
    teal: '#4EC9B0',
    peach: '#CE9178',
  },
}

const THEME_TOML = `[theme]
name = "vsc-dark-modern"

[theme.custom]
panel_bg = "#1F1F1F"
surface_dim = "#313131"
surface0 = "#3C3C3C"
surface1 = "#454545"
overlay0 = "#6E7681"
overlay1 = "#868686"
text = "#CCCCCC"
subtext0 = "#9D9D9D"
accent = "#F5A9B8"
mauve = "#C586C0"
green = "#2EA043"
yellow = "#DCDCAA"
red = "#F85149"
blue = "#0078D4"
teal = "#4EC9B0"
peach = "#CE9178"`

test('uses an exact 100-character divider', () => {
  assert.equal(CONFIG_DIVIDER, '#'.repeat(100))
})

test('renders the complete theme JSON schema as TOML', () => {
  assert.equal(renderTheme(THEME), THEME_TOML)

  const missingColor = { ...THEME, custom: { ...THEME.custom } }
  delete missingColor.custom.accent
  assert.throws(() => renderTheme(missingColor), /must contain exactly/)
  assert.throws(() => renderTheme({ ...THEME, extra: true }), /must contain exactly/)
  assert.throws(() => renderTheme({ ...THEME, name: '' }), /non-empty string/)
})

test('replaces generated sections and preserves the manual tail', () => {
  const shared = 'onboarding = false\n'
  const manualTail = '\r\n\r\n# Manual settings\r\n[experimental]\r\nkitty_graphics = true\r\n'
  const current = [
    'onboarding = true',
    CONFIG_DIVIDER,
    '[theme]\nname = "old"',
    CONFIG_DIVIDER,
  ].join('\n\n') + manualTail
  const expected = [
    'onboarding = false',
    CONFIG_DIVIDER,
    THEME_TOML,
    CONFIG_DIVIDER,
  ].join('\n\n') + manualTail

  assert.equal(renderConfig(shared, THEME_TOML, current), expected)
  assert.equal(renderConfig(shared, THEME_TOML, expected), expected)
})

test('preserves a divider-free config as the initial manual tail', () => {
  const current = '# Manual settings\n[experimental]\nkitty_graphics = true\n'
  const expected = [
    'onboarding = false',
    CONFIG_DIVIDER,
    THEME_TOML,
    CONFIG_DIVIDER,
    current.trimEnd(),
  ].join('\n\n') + '\n'

  assert.equal(renderConfig('onboarding = false\n', THEME_TOML, current), expected)
})

test('migrates the legacy one-divider format without retaining its generated theme', () => {
  const current = `onboarding = true\n\n${CONFIG_DIVIDER}\n\n[theme]\nname = "old"\n`
  const expected = [
    'onboarding = false',
    CONFIG_DIVIDER,
    THEME_TOML,
    CONFIG_DIVIDER,
    '',
  ].join('\n\n')

  assert.equal(renderConfig('onboarding = false\n', THEME_TOML, current), expected)
})

test('syncs all three sections and skips an unchanged config', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const sharedPath = path.join(tempDir, 'config.shared.toml')
  const themePath = path.join(tempDir, 'local.json')
  const configPath = path.join(tempDir, 'config.toml')
  const current = `old\n\n${CONFIG_DIVIDER}\n\nold theme\n\n${CONFIG_DIVIDER}\n\n# manual\n`
  const expected = [
    'onboarding = false',
    CONFIG_DIVIDER,
    THEME_TOML,
    CONFIG_DIVIDER,
    '# manual',
  ].join('\n\n') + '\n'

  await Promise.all([
    fs.writeFile(sharedPath, 'onboarding = false\n', 'utf8'),
    fs.writeFile(themePath, JSON.stringify(THEME), 'utf8'),
    fs.writeFile(configPath, current, 'utf8'),
  ])

  assert.equal(await syncConfig(sharedPath, themePath, configPath), true)
  assert.equal(await fs.readFile(configPath, 'utf8'), expected)
  assert.equal(await syncConfig(sharedPath, themePath, configPath), false)
})

test('does not overwrite config when theme input is invalid or missing', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const sharedPath = path.join(tempDir, 'config.shared.toml')
  const themePath = path.join(tempDir, 'local.json')
  const configPath = path.join(tempDir, 'config.toml')
  const current = '# keep me\n'
  await Promise.all([
    fs.writeFile(sharedPath, 'onboarding = false\n', 'utf8'),
    fs.writeFile(themePath, '{', 'utf8'),
    fs.writeFile(configPath, current, 'utf8'),
  ])

  await assert.rejects(syncConfig(sharedPath, themePath, configPath), SyntaxError)
  assert.equal(await fs.readFile(configPath, 'utf8'), current)

  await fs.writeFile(themePath, JSON.stringify({ name: 'broken', custom: {} }), 'utf8')
  await assert.rejects(syncConfig(sharedPath, themePath, configPath), TypeError)
  assert.equal(await fs.readFile(configPath, 'utf8'), current)

  await fs.unlink(themePath)
  await assert.rejects(
    syncConfig(sharedPath, themePath, configPath),
    error => error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT',
  )
  assert.equal(await fs.readFile(configPath, 'utf8'), current)
})

test('cleans up the temporary file when atomic replacement fails', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const configPath = path.join(tempDir, 'config.toml')
  const markerPath = path.join(configPath, 'manual-tail')
  await fs.mkdir(configPath)
  await fs.writeFile(markerPath, 'keep me\n', 'utf8')

  await assert.rejects(writeFileAtomically(configPath, 'replacement\n'))
  assert.deepEqual(await fs.readdir(tempDir), ['config.toml'])
  assert.equal(await fs.readFile(markerPath, 'utf8'), 'keep me\n')
})

test('propagates config read errors other than ENOENT', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const sharedPath = path.join(tempDir, 'config.shared.toml')
  const themePath = path.join(tempDir, 'local.json')
  await Promise.all([
    fs.writeFile(sharedPath, 'onboarding = false\n', 'utf8'),
    fs.writeFile(themePath, JSON.stringify(THEME), 'utf8'),
  ])

  await assert.rejects(
    syncConfig(sharedPath, themePath, tempDir),
    error => error && typeof error === 'object' && 'code' in error && error.code === 'EISDIR',
  )
})
