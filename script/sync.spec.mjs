import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import test from 'node:test'

import { CONFIG_DIVIDER, renderConfig, syncConfig } from './sync.mjs'

test('uses an exact 100-character divider', () => {
  assert.equal(CONFIG_DIVIDER, '#'.repeat(100))
})

test('replaces the prefix and adds a blank line before the suffix', () => {
  const shared = 'onboarding = false\n\n'

  for (const [suffix, expectedSuffix] of [
    ['\n[theme]\nname = "vsc-dark-modern"\n', '\n\n[theme]\nname = "vsc-dark-modern"\n'],
    [
      '\r\n[theme]\r\nname = "vsc-dark-modern"\r\n',
      '\r\n\r\n[theme]\r\nname = "vsc-dark-modern"\r\n',
    ],
    ['\n\n[theme]\nname = "vsc-dark-modern"\n', '\n\n[theme]\nname = "vsc-dark-modern"\n'],
    ['', '\n\n'],
  ]) {
    const current = `onboarding = true\n${CONFIG_DIVIDER}${suffix}`
    const expected = `onboarding = false\n\n${CONFIG_DIVIDER}${expectedSuffix}`

    assert.equal(renderConfig(shared, current), expected)
  }
})

test('adds a trailing divider when none exists', () => {
  const expected = `onboarding = false\n\n${CONFIG_DIVIDER}\n\n`

  assert.equal(renderConfig('onboarding = false\n', ''), expected)
  assert.equal(renderConfig('onboarding = false\n', 'legacy = true\n'), expected)
  assert.equal(renderConfig('onboarding = false\n', `${CONFIG_DIVIDER}\r`), expected)
  assert.equal(
    renderConfig('onboarding = false\n', `${'#'.repeat(101)}\n[theme]\n`),
    expected,
  )
})

test('creates a missing config and skips an unchanged config', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const sharedPath = path.join(tempDir, 'config.shared.toml')
  const configPath = path.join(tempDir, 'config.toml')
  const expected = `onboarding = false\n\n${CONFIG_DIVIDER}\n\n`
  await fs.writeFile(sharedPath, 'onboarding = false\n', 'utf8')

  assert.equal(await syncConfig(sharedPath, configPath), true)
  assert.equal(await fs.readFile(configPath, 'utf8'), expected)
  assert.equal(await syncConfig(sharedPath, configPath), false)
})

test('propagates config read errors other than ENOENT', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'herdr-sync-spec-'))
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }))

  const sharedPath = path.join(tempDir, 'config.shared.toml')
  await fs.writeFile(sharedPath, 'onboarding = false\n', 'utf8')

  await assert.rejects(
    syncConfig(sharedPath, tempDir),
    error => error && typeof error === 'object' && 'code' in error && error.code === 'EISDIR',
  )
})
