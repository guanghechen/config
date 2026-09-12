import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import {
  GHOSTTY_SHADERS,
  applyGhosttyThemeAppearance,
  listGhosttyShaders,
  selectGhosttyShader,
  validateGhosttyThemeAppearance,
} from '../asset/theme/template/ghostty/shader.mjs'

const shaderNames = [
  'off', 'cubes', 'fireworks-rockets', 'gears-and-belts', 'inside-the-matrix',
  'matrix-hallway', 'mnoise', 'neuro-noise', 'sparks-from-fire', 'starfield',
]
const legacyFiles = [
  'local/shader-dark.conf', 'local/shader-light.conf', 'theme-dark.conf', 'theme-light.conf',
]
const stateFiles = [
  'local/shader', 'local/theme.conf', 'local/shader.conf', 'local/appearance', ...legacyFiles,
]

/** @param {import('node:test').TestContext} t @param {'dark'|'light'} [appearance] */
async function fixture(t, appearance = 'dark') {
  const home = await fs.mkdtemp(path.join(os.tmpdir(), 'ghostty-shader-test-'))
  t.after(() => fs.rm(home, { recursive: true, force: true }))
  await fs.mkdir(path.join(home, 'local'))
  for (const mode of ['dark', 'light']) {
    await fs.mkdir(path.join(home, 'shaders', mode), { recursive: true })
    for (const name of shaderNames.slice(1)) {
      await fs.writeFile(path.join(home, 'shaders', mode, `${name}.glsl`), '// fixture\n')
    }
  }
  await fs.writeFile(path.join(home, 'local/shader'), 'off\n')
  await fs.writeFile(path.join(home, 'local/appearance'), `${appearance}\n`)
  await fs.writeFile(path.join(home, 'local/theme.conf'), 'original theme\n')
  await fs.writeFile(path.join(home, 'local/shader.conf'), '')
  return home
}

/** @param {import('node:test').TestContext} t @param {'dark'|'light'} [appearance] */
async function legacyFixture(t, appearance = 'light') {
  const home = await fixture(t, appearance)
  await fs.unlink(path.join(home, 'local/shader'))
  await fs.writeFile(path.join(home, 'local/shader-dark.conf'), 'custom-shader = ../shaders/dark/inside-the-matrix.glsl\n')
  await fs.writeFile(path.join(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
  const shader = appearance === 'light' ? 'neuro-noise' : 'inside-the-matrix'
  await fs.writeFile(path.join(home, 'local/shader.conf'), `custom-shader = ../shaders/${appearance}/${shader}.glsl\n`)
  return home
}

/** @param {string} home @param {string} filename */
async function read(home, filename) {
  return fs.readFile(path.join(home, filename), 'utf8')
}

/** @param {string} home */
async function snapshot(home) {
  return Promise.all(stateFiles.map(async filename => {
    try {
      return await read(home, filename)
    } catch (error) {
      if (error instanceof Error && 'code' in error && error.code === 'ENOENT') return undefined
      throw error
    }
  }))
}

/** @param {string} home */
async function assertNoLegacy(home) {
  for (const filename of legacyFiles) {
    await assert.rejects(fs.stat(path.join(home, filename)), { code: 'ENOENT' })
  }
}

describe('Ghostty shared shader selection', () => {
  for (const appearance of /** @type {const} */ (['dark', 'light'])) {
    it(`stores one name and derives the ${appearance} path for every selection`, async t => {
      const home = await fixture(t, appearance)
      assert.deepEqual(GHOSTTY_SHADERS[appearance], shaderNames)
      assert.deepEqual(await listGhosttyShaders({ home }), shaderNames)
      for (const shader of shaderNames) {
        assert.deepEqual(await selectGhosttyShader({ home, shader }), { appearance, shader })
        assert.equal(await read(home, 'local/shader'), `${shader}\n`)
        const active = shader === 'off' ? '' : `custom-shader = ../shaders/${appearance}/${shader}.glsl\n`
        assert.equal(await read(home, 'local/shader.conf'), active)
        await assertNoLegacy(home)
      }
    })

    it(`cycles through the same names, including off, in ${appearance}`, async t => {
      const home = await fixture(t, appearance)
      assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'cubes')
      assert.equal((await selectGhosttyShader({ home, previous: true })).shader, 'off')
      assert.equal((await selectGhosttyShader({ home, previous: true })).shader, 'starfield')
      assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'off')
    })
  }

  it('keeps the chosen name across theme switches and continues cycling from it', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/cubes.glsl\n')
    assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'fireworks-rockets')
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/fireworks-rockets.glsl\n')
    assert.equal((await selectGhosttyShader({ home, previous: true })).shader, 'cubes')
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
    await assertNoLegacy(home)
  })

  it('keeps off disabled when the appearance changes', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'off' })
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader'), 'off\n')
    assert.equal(await read(home, 'local/shader.conf'), '')
  })

  it('migrates the active effect instead of restoring the destination appearance preference', async t => {
    const home = await legacyFixture(t)
    await fs.writeFile(path.join(home, 'theme-dark.conf'), 'custom-shader = shaders/dark/cubes.glsl\n')
    const before = await snapshot(home)
    assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'dark' }), {
      appearance: 'dark', shader: 'neuro-noise',
    })
    assert.deepEqual(await snapshot(home), before)
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/neuro-noise.glsl\n')
    await assertNoLegacy(home)
  })

  for (const shader of ['cubes', 'inside-the-matrix']) {
    it(`migrates the active ${shader}-light alias to a shared name`, async t => {
      const home = await legacyFixture(t)
      await fs.writeFile(path.join(home, 'local/shader.conf'), `custom-shader = ../shaders/${shader}-light.glsl\n`)
      await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
      assert.equal(await read(home, 'local/shader'), `${shader}\n`)
      assert.equal(await read(home, 'local/shader.conf'), `custom-shader = ../shaders/dark/${shader}.glsl\n`)
      await assertNoLegacy(home)
    })
  }

  it('migrates an explicitly disabled active effect as off', async t => {
    const home = await legacyFixture(t)
    await fs.writeFile(path.join(home, 'local/shader.conf'), '')
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader'), 'off\n')
    assert.equal(await read(home, 'local/shader.conf'), '')
    await assertNoLegacy(home)
  })

  it('uses the current appearance preference when no active config exists', async t => {
    const home = await legacyFixture(t, 'dark')
    await fs.unlink(path.join(home, 'local/shader.conf'))
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader'), 'inside-the-matrix\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/inside-the-matrix.glsl\n')
  })

  it('prefers the shared name over stale derived and per-appearance state', async t => {
    const home = await legacyFixture(t)
    await fs.writeFile(path.join(home, 'local/shader'), 'cubes\n')
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader'), 'cubes\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/cubes.glsl\n')
    await assertNoLegacy(home)
  })

  it('does not require obsolete shader files before retiring their selections', async t => {
    const home = await legacyFixture(t)
    await fs.unlink(path.join(home, 'shaders/dark/inside-the-matrix.glsl'))
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
    await assertNoLegacy(home)
  })

  it('rejects a missing destination shader without changing any state', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    await fs.unlink(path.join(home, 'shaders/light/neuro-noise.glsl'))
    const before = await snapshot(home)
    await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }), /Cannot find shader:.*light[/\\]neuro-noise\.glsl/)
    assert.deepEqual(await snapshot(home), before)
  })

  for (const name of ['', 'cubes-light', '../cubes', 'unknown']) {
    it(`refuses an invalid shared selection without overwriting state: ${name || '<empty>'}`, async t => {
      const home = await fixture(t)
      await fs.writeFile(path.join(home, 'local/shader'), name)
      const before = await snapshot(home)
      await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }), /Unknown Ghostty shader selection/)
      assert.deepEqual(await snapshot(home), before)
    })
  }

  for (const content of [
    'custom-shader = shaders/dark/cubes.glsl\n',
    'custom-shader = shaders/light/../../cursor.glsl\n',
    'custom-shader = /tmp/custom.glsl\n',
  ]) {
    it(`refuses to delete an unrecognized legacy selection: ${content.trim()}`, async t => {
      const home = await legacyFixture(t)
      await fs.writeFile(path.join(home, 'local/shader-light.conf'), content)
      const before = await snapshot(home)
      await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }))
      assert.deepEqual(await snapshot(home), before)
    })
  }

  it('allows replacing a known selection whose old shader file is missing', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    await fs.unlink(path.join(home, 'shaders/dark/cubes.glsl'))
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
  })

  for (const version of [1, 2, 3]) {
    it(`recovers a version ${version} journal before migrating to shared state`, async t => {
      const home = await fixture(t, 'light')
      await fs.unlink(path.join(home, 'local/shader'))
      await fs.unlink(path.join(home, 'local/shader.conf'))
      const interrupted = version === 2 ? 'theme-light.conf' : 'local/shader-light.conf'
      await fs.writeFile(path.join(home, interrupted), 'partial update\n')
      const journal = {
        version,
        files: [{ target: 'saved-light', existed: true, content: 'custom-shader = shaders/cubes-light.glsl\n' }],
      }
      await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
      assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'fireworks-rockets')
      assert.equal(await read(home, 'local/shader'), 'fireworks-rockets\n')
      await assertNoLegacy(home)
      await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.transaction.json')), { code: 'ENOENT' })
    })
  }

  it('recovers the shared name and active path from a version 4 journal', async t => {
    const home = await fixture(t, 'light')
    await fs.writeFile(path.join(home, 'local/shader'), 'starfield\n')
    await fs.writeFile(path.join(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/starfield.glsl\n')
    const journal = {
      version: 4,
      files: [
        { target: 'selection', existed: true, content: 'neuro-noise\n' },
        { target: 'active', existed: true, content: 'custom-shader = ../shaders/light/neuro-noise.glsl\n' },
      ],
    }
    await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
    assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'sparks-from-fire')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/sparks-from-fire.glsl\n')
  })

  it('restores retired files after an interrupted first migration', async t => {
    const home = await fixture(t, 'light')
    const journal = {
      version: 4,
      files: [
        { target: 'selection', existed: false, content: '' },
        { target: 'active', existed: true, content: 'custom-shader = ../shaders/light/neuro-noise.glsl\n' },
        { target: 'saved-dark', existed: true, content: 'custom-shader = ../shaders/dark/inside-the-matrix.glsl\n' },
        { target: 'saved-light', existed: true, content: 'custom-shader = ../shaders/light/neuro-noise.glsl\n' },
      ],
    }
    await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
    await validateGhosttyThemeAppearance({ home, appearance: 'dark' })
    await assert.rejects(fs.stat(path.join(home, 'local/shader')), { code: 'ENOENT' })
    assert.equal(await read(home, 'local/shader-dark.conf'), journal.files[2].content)
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/neuro-noise.glsl\n')
    await assertNoLegacy(home)
  })

  it('serializes selection and theme changes without losing the shared choice', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    await Promise.all([
      selectGhosttyShader({ home, shader: 'neuro-noise' }),
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' }),
    ])
    assert.equal(await read(home, 'local/appearance'), 'light\n')
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
  })
})
