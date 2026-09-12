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
const stateFiles = [
  'local/shader-dark.conf', 'local/shader-light.conf', 'local/theme.conf', 'local/shader.conf',
  'local/appearance', 'theme-dark.conf', 'theme-light.conf',
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
    await fs.writeFile(path.join(home, `local/shader-${mode}.conf`), '')
  }
  await fs.writeFile(path.join(home, 'local/appearance'), `${appearance}\n`)
  await fs.writeFile(path.join(home, 'local/theme.conf'), 'original theme\n')
  await fs.writeFile(path.join(home, 'local/shader.conf'), '')
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

describe('Ghostty shader appearance directories', () => {
  for (const appearance of /** @type {const} */ (['dark', 'light'])) {
    it(`lists and selects every shared name in ${appearance}`, async t => {
      const home = await fixture(t, appearance)
      assert.deepEqual(GHOSTTY_SHADERS[appearance], shaderNames)
      assert.deepEqual(await listGhosttyShaders({ home }), shaderNames)
      const other = appearance === 'dark' ? 'light' : 'dark'
      for (const shader of shaderNames) {
        assert.deepEqual(await selectGhosttyShader({ home, shader }), { appearance, shader })
        const saved = shader === 'off' ? '' : `custom-shader = ../shaders/${appearance}/${shader}.glsl\n`
        const active = shader === 'off' ? '' : `custom-shader = ../shaders/${appearance}/${shader}.glsl\n`
        assert.equal(await read(home, `local/shader-${appearance}.conf`), saved)
        assert.equal(await read(home, 'local/shader.conf'), active)
        assert.equal(await read(home, `local/shader-${other}.conf`), '')
        await assert.rejects(fs.stat(path.join(home, 'theme-dark.conf')), { code: 'ENOENT' })
        await assert.rejects(fs.stat(path.join(home, 'theme-light.conf')), { code: 'ENOENT' })
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

  it('restores independent selections when the theme appearance changes', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/cubes.glsl\n')
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
    assert.equal(await read(home, 'local/theme.conf'), 'light theme\n')
    assert.equal(await read(home, 'local/appearance'), 'light\n')
  })

  for (const shader of ['cubes', 'inside-the-matrix']) {
    it(`migrates the saved ${shader}-light alias without mutating during prepare`, async t => {
      const home = await fixture(t, 'light')
      await fs.writeFile(path.join(home, 'theme-light.conf'), `custom-shader = shaders/${shader}-light.glsl\n`)
      await fs.writeFile(path.join(home, 'theme-dark.conf'), 'custom-shader = shaders/starfield.glsl\n')
      const before = await snapshot(home)
      assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'light' }), { appearance: 'light', shader })
      assert.deepEqual(await snapshot(home), before)
      await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' })
      assert.equal(await read(home, 'local/shader-light.conf'), `custom-shader = ../shaders/light/${shader}.glsl\n`)
      assert.equal(await read(home, 'local/shader-dark.conf'), 'custom-shader = ../shaders/dark/starfield.glsl\n')
      assert.equal(await read(home, 'local/shader.conf'), `custom-shader = ../shaders/light/${shader}.glsl\n`)
      await assert.rejects(fs.stat(path.join(home, 'theme-dark.conf')), { code: 'ENOENT' })
      await assert.rejects(fs.stat(path.join(home, 'theme-light.conf')), { code: 'ENOENT' })
    })
  }

  it('normalizes older local selections without creating root configs', async t => {
    const home = await fixture(t, 'light')
    await fs.unlink(path.join(home, 'local/shader-dark.conf'))
    await fs.unlink(path.join(home, 'local/shader-light.conf'))
    const dark = 'custom-shader = ../shaders/mnoise.glsl\n'
    const light = 'custom-shader = ../shaders/cubes-light.glsl\n'
    await fs.writeFile(path.join(home, 'local/shader-dark.conf'), dark)
    await fs.writeFile(path.join(home, 'local/shader-light.conf'), light)
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' })
    assert.equal(await read(home, 'local/shader-dark.conf'), 'custom-shader = ../shaders/dark/mnoise.glsl\n')
    assert.equal(await read(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/cubes.glsl\n')
    await assert.rejects(fs.stat(path.join(home, 'theme-dark.conf')), { code: 'ENOENT' })
    await assert.rejects(fs.stat(path.join(home, 'theme-light.conf')), { code: 'ENOENT' })
  })

  for (const active of [
    'custom-shader = ../shaders/neuro-noise.glsl\n',
    'custom-shader = ../shaders/light/neuro-noise.glsl\n',
  ]) {
    it(`keeps an active light Neuro Noise selection when migrating ${active.trim()}`, async t => {
      const home = await fixture(t, 'light')
      await fs.unlink(path.join(home, 'local/shader-dark.conf'))
      await fs.unlink(path.join(home, 'local/shader-light.conf'))
      await fs.writeFile(path.join(home, 'local/shader.conf'), active)
      await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
      assert.equal(await read(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
      assert.equal(await read(home, 'local/shader-dark.conf'), '')
      assert.equal(await read(home, 'local/shader.conf'), '')
    })
  }

  it('uses a qualified active path ahead of a stale appearance marker', async t => {
    const home = await fixture(t, 'dark')
    await fs.unlink(path.join(home, 'local/shader-light.conf'))
    await fs.writeFile(path.join(home, 'local/shader.conf'), 'custom-shader = ../shaders/light/starfield.glsl\n')
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/starfield.glsl\n')
    assert.equal(await read(home, 'local/shader-dark.conf'), '')
  })

  it('keeps an explicit root off selection ahead of stale local state during migration', async t => {
    const home = await fixture(t, 'light')
    await fs.writeFile(path.join(home, 'theme-light.conf'), '')
    await fs.writeFile(path.join(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/cubes-light.glsl\n')
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader-light.conf'), '')
    assert.equal(await read(home, 'local/shader.conf'), '')
  })

  it('rejects a missing light file even when its dark counterpart exists', async t => {
    const home = await fixture(t, 'light')
    await fs.unlink(path.join(home, 'shaders/light/cubes.glsl'))
    const before = await snapshot(home)
    await assert.rejects(selectGhosttyShader({ home, shader: 'cubes' }), /Cannot find shader:.*light[/\\]cubes\.glsl/)
    assert.deepEqual(await snapshot(home), before)
  })

  for (const content of [
    'custom-shader = shaders/dark/cubes.glsl\n',
    'custom-shader = shaders/light/cubes-light.glsl\n',
    'custom-shader = shaders/light/../../cursor.glsl\n',
    'custom-shader = /tmp/custom.glsl\n',
    'custom-shader = shaders/light/off.glsl\n',
  ]) {
    it(`rejects an invalid light selection without overwriting state: ${content.trim()}`, async t => {
      const home = await fixture(t, 'light')
      await fs.writeFile(path.join(home, 'local/shader-light.conf'), content)
      const before = await snapshot(home)
      await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }))
      assert.deepEqual(await snapshot(home), before)
    })
  }

  it('replaces a selected shader whose old file was removed', async t => {
    const home = await fixture(t, 'light')
    await fs.writeFile(path.join(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/cubes-light.glsl\n')
    await fs.unlink(path.join(home, 'shaders/light/cubes.glsl'))
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    assert.equal(await read(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/neuro-noise.glsl\n')
  })

  for (const version of [1, 2, 3]) {
    it(`recovers a version ${version} journal using its original saved-file location`, async t => {
      const home = await fixture(t, 'light')
      const interrupted = version === 2 ? 'theme-light.conf' : 'local/shader-light.conf'
      await fs.writeFile(path.join(home, interrupted), 'partial update\n')
      const journal = {
        version,
        files: [{
          target: 'saved-light', existed: true,
          content: 'custom-shader = shaders/cubes-light.glsl\n',
        }],
      }
      await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
      assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'fireworks-rockets')
      assert.equal(await read(home, 'local/shader-light.conf'), 'custom-shader = ../shaders/light/fireworks-rockets.glsl\n')
      await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.transaction.json')), { code: 'ENOENT' })
      await assert.rejects(fs.stat(path.join(home, 'theme-light.conf')), { code: 'ENOENT' })
    })
  }

  it('restores deleted root files from an interrupted migration before retrying', async t => {
    const home = await fixture(t)
    const oldRoot = 'custom-shader = shaders/mnoise.glsl\n'
    await fs.writeFile(path.join(home, 'local/shader-dark.conf'), 'custom-shader = ../shaders/dark/mnoise.glsl\n')
    const journal = {
      version: 3,
      files: [
        { target: 'saved-dark', existed: true, content: '' },
        { target: 'legacy-dark', existed: true, content: oldRoot },
      ],
    }
    await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
    await validateGhosttyThemeAppearance({ home, appearance: 'dark' })
    assert.equal(await read(home, 'theme-dark.conf'), oldRoot)
    assert.equal(await read(home, 'local/shader-dark.conf'), '')
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'new theme\n' })
    assert.equal(await read(home, 'local/shader-dark.conf'), 'custom-shader = ../shaders/dark/mnoise.glsl\n')
    await assert.rejects(fs.stat(path.join(home, 'theme-dark.conf')), { code: 'ENOENT' })
  })

  it('keeps root files when another migration candidate cannot be validated', async t => {
    const home = await fixture(t, 'light')
    await fs.writeFile(path.join(home, 'theme-dark.conf'), 'custom-shader = shaders/dark/cubes.glsl\n')
    await fs.writeFile(path.join(home, 'theme-light.conf'), 'custom-shader = shaders/light/neuro-noise.glsl\n')
    await fs.unlink(path.join(home, 'shaders/dark/cubes.glsl'))
    const before = await snapshot(home)
    await assert.rejects(selectGhosttyShader({ home, shader: 'neuro-noise' }), /Cannot find shader/)
    assert.deepEqual(await snapshot(home), before)
  })

  it('keeps the active directory consistent during concurrent selection and theme apply', async t => {
    const home = await fixture(t)
    await Promise.all([
      selectGhosttyShader({ home, next: true }),
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' }),
    ])
    const saved = await read(home, 'local/shader-light.conf')
    assert.equal(await read(home, 'local/appearance'), 'light\n')
    assert.equal(await read(home, 'local/theme.conf'), 'light theme\n')
    assert.equal(await read(home, 'local/shader.conf'), saved)
  })
})
