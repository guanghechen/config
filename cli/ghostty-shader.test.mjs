import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { promisify } from 'node:util'

import { XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR } from '#env'

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
  'local/shader',
  'local/shader-dark.conf', 'local/shader-light.conf', 'theme-dark.conf', 'theme-light.conf',
]
const stateFiles = [
  'local/theme.conf', 'local/shader.conf', 'local/appearance', ...legacyFiles,
]
const wallpaperConfig = `background-image = ${path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.png')}\n`
const noWallpaperConfig = 'background-image =\n'
const execFileAsync = promisify(execFile)

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
  await fs.writeFile(path.join(home, 'local/appearance'), `${appearance}\n`)
  await fs.writeFile(path.join(home, 'local/theme.conf'), 'original theme\n')
  await fs.writeFile(path.join(home, 'local/shader.conf'), noWallpaperConfig)
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
    it(`stores every ${appearance} selection only in shader.conf`, async t => {
      const home = await fixture(t, appearance)
      assert.deepEqual(GHOSTTY_SHADERS[appearance], shaderNames)
      assert.deepEqual(await listGhosttyShaders({ home }), shaderNames)
      for (const shader of shaderNames) {
        assert.deepEqual(await selectGhosttyShader({ home, shader }), { appearance, shader })
        const active = shader === 'off'
          ? appearance === 'dark' ? wallpaperConfig : noWallpaperConfig
          : `${noWallpaperConfig}custom-shader = ../shaders/${appearance}/${shader}.glsl\n`
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
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/cubes.glsl\n`)
    assert.equal((await selectGhosttyShader({ home, next: true })).shader, 'fireworks-rockets')
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/dark/fireworks-rockets.glsl\n`)
    assert.equal((await selectGhosttyShader({ home, previous: true })).shader, 'cubes')
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/neuro-noise.glsl\n`)
    await assertNoLegacy(home)
  })

  it('shows the wallpaper only in dark appearance while keeping the shader off', async t => {
    const home = await fixture(t)
    await fs.writeFile(path.join(home, 'shader.conf'), 'custom-shader = shaders/cursor.glsl\n')
    await selectGhosttyShader({ home, shader: 'off' })
    assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    await assertNoLegacy(home)
    assert.equal(await read(home, 'local/shader.conf'), noWallpaperConfig)
    await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'dark theme\n' })
    await assertNoLegacy(home)
    assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    assert.equal(await read(home, 'shader.conf'), 'custom-shader = shaders/cursor.glsl\n')
  })

  it('clears the wallpaper for a background shader and restores it when cycling to off', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'off' })
    await selectGhosttyShader({ home, next: true })
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/dark/cubes.glsl\n`)
    await selectGhosttyShader({ home, previous: true })
    assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    assert.equal(await read(home, 'local/theme.conf'), 'original theme\n')
  })

  it('leaves permanent background settings in the main config across all states', async t => {
    const home = await fixture(t)
    const mainConfig = [
      'background-opacity = 0.7',
      'background-opacity-cells = true',
      'background-image-opacity = 0.3',
      'background-image-fit = contain',
      'background-image-position = center',
      'background-image-repeat = true',
      'background-blur = false',
      'config-file = local/shader.conf',
      '',
    ].join('\n')
    await fs.writeFile(path.join(home, 'config'), mainConfig)
    for (const appearance of /** @type {const} */ (['dark', 'light'])) {
      await applyGhosttyThemeAppearance({ home, appearance, themeContent: 'theme\n' })
      for (const shader of ['off', 'cubes']) {
        await selectGhosttyShader({ home, shader })
        assert.equal(await read(home, 'config'), mainConfig)
        const keys = (await read(home, 'local/shader.conf')).trim().split('\n')
          .map(line => line.split(' =')[0])
        assert.deepEqual(keys, shader === 'off'
          ? ['background-image']
          : ['background-image', 'custom-shader'])
      }
    }
  })

  for (const appearance of /** @type {const} */ (['dark', 'light'])) {
    for (const shader of ['off', 'cubes']) {
      it(`reads ${appearance}/${shader} directly from shader.conf without a sidecar`, async t => {
        const home = await fixture(t, appearance)
        await selectGhosttyShader({ home, shader })
        const before = await snapshot(home)
        assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance }), { appearance, shader })
        assert.deepEqual(await snapshot(home), before)
        await applyGhosttyThemeAppearance({ home, appearance, themeContent: 'new theme\n' })
        await assertNoLegacy(home)
        assert.equal(await read(home, 'local/shader.conf'), before[1])
      })
    }
  }

  for (const content of [
    '',
    'background-image = /tmp/custom.png\n',
    `${wallpaperConfig}custom-shader = /tmp/custom.glsl\n`,
    'background-image =\ncustom-shader = /tmp/custom.glsl\n',
    'custom-shader = shaders/cubes-light.glsl\n',
    'background-image =\nbackground-opacity = 1\n',
    'background-image =\ncustom-shader = ../shaders/light/../../cursor.glsl\n',
  ]) {
    it(`refuses to replace an unrecognized active background: ${content.trim()}`, async t => {
      const home = await fixture(t)
      await fs.writeFile(path.join(home, 'local/shader.conf'), content)
      const before = await snapshot(home)
      await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'new theme\n' }), /Unrecognized Ghostty shader config/)
      assert.deepEqual(await snapshot(home), before)
    })
  }

  it('ignores retired state files without deleting them or blocking the current selection', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    for (const filename of legacyFiles) {
      await fs.writeFile(path.join(home, filename), 'unrecognized legacy content\n')
    }
    const before = await snapshot(home)
    assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'light' }), {
      appearance: 'light', shader: 'cubes',
    })
    assert.deepEqual(await snapshot(home), before)
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/cubes.glsl\n`)
    for (const filename of legacyFiles) {
      assert.equal(await read(home, filename), 'unrecognized legacy content\n')
    }
  })

  it('defaults to off when the active config is missing', async t => {
    const home = await fixture(t)
    await fs.unlink(path.join(home, 'local/shader.conf'))
    await fs.writeFile(path.join(home, 'local/shader'), 'neuro-noise\n')
    const before = await snapshot(home)
    assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'dark' }), {
      appearance: 'dark', shader: 'off',
    })
    assert.deepEqual(await snapshot(home), before)
    await selectGhosttyShader({ home, shader: 'off' })
    assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    assert.equal(await read(home, 'local/shader'), 'neuro-noise\n')
  })

  it('rejects a missing destination shader without changing any state', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    await fs.unlink(path.join(home, 'shaders/light/neuro-noise.glsl'))
    const before = await snapshot(home)
    await assert.rejects(applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }), /Cannot find shader:.*light[/\\]neuro-noise\.glsl/)
    assert.deepEqual(await snapshot(home), before)
  })

  it('allows replacing a known selection whose old shader file is missing', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    await fs.unlink(path.join(home, 'shaders/dark/cubes.glsl'))
    await selectGhosttyShader({ home, shader: 'neuro-noise' })
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/dark/neuro-noise.glsl\n`)
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
    await assertNoLegacy(home)
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/neuro-noise.glsl\n`)
  })

  it('restores all current files from a pending journal before selecting a shader', async t => {
    const home = await fixture(t)
    await fs.writeFile(path.join(home, 'local/theme.conf'), 'partial theme\n')
    await fs.writeFile(path.join(home, 'local/shader.conf'), 'partial shader\n')
    const journal = {
      version: 4,
      files: [
        { target: 'theme', existed: true, content: 'light theme\n' },
        { target: 'active', existed: true, content: `${noWallpaperConfig}custom-shader = ../shaders/light/neuro-noise.glsl\n` },
        { target: 'appearance', existed: true, content: 'light\n' },
      ],
    }
    await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
    assert.deepEqual(await selectGhosttyShader({ home, next: true }), {
      appearance: 'light', shader: 'sparks-from-fire',
    })
    assert.equal(await read(home, 'local/theme.conf'), 'light theme\n')
    assert.equal(await read(home, 'local/appearance'), 'light\n')
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/sparks-from-fire.glsl\n`)
    await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.transaction.json')), { code: 'ENOENT' })
  })

  it('removes newly created files when recovering their absent snapshots', async t => {
    const home = await fixture(t)
    const journal = {
      version: 4,
      files: [
        { target: 'theme', existed: false, content: '' },
        { target: 'active', existed: false, content: '' },
      ],
    }
    await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), JSON.stringify(journal))
    assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'dark' }), {
      appearance: 'dark', shader: 'off',
    })
    await assert.rejects(fs.stat(path.join(home, 'local/theme.conf')), { code: 'ENOENT' })
    await assert.rejects(fs.stat(path.join(home, 'local/shader.conf')), { code: 'ENOENT' })
  })

  for (const journal of [
    { version: 3, files: [{ target: 'theme', existed: true, content: 'old theme\n' }] },
    { version: 4, files: [
      { target: 'theme', existed: true, content: 'old theme\n' },
      { target: 'selection', existed: true, content: 'off\n' },
    ] },
    { version: 4, files: [
      { target: 'theme', existed: true, content: 'old theme\n' },
      { target: 'theme', existed: false, content: '' },
    ] },
    { version: 4, files: [
      { target: 'theme', existed: true, content: 'old theme\n' },
      { target: 'active', existed: true, content: null },
    ] },
  ]) {
    it(`rejects the complete invalid journal before restoring any file: ${JSON.stringify(journal)}`, async t => {
      const home = await fixture(t)
      const before = await snapshot(home)
      const content = JSON.stringify(journal)
      await fs.writeFile(path.join(home, 'local/.shader-state.transaction.json'), content)
      await assert.rejects(validateGhosttyThemeAppearance({ home, appearance: 'dark' }), /Invalid Ghostty shader transaction/)
      assert.deepEqual(await snapshot(home), before)
      assert.equal(await read(home, 'local/.shader-state.transaction.json'), content)
      await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.lock')), { code: 'ENOENT' })
    })
  }

  it('rolls back the complete state when a later file replacement fails', async t => {
    const home = await fixture(t)
    const before = await snapshot(home)
    const rename = fs.rename
    let failed = false
    t.mock.method(fs, 'rename', async (source, destination) => {
      if (!failed && destination === path.join(home, 'local/appearance')) {
        failed = true
        throw Object.assign(new Error('Injected appearance replacement failure'), { code: 'EIO' })
      }
      return rename(source, destination)
    })
    await assert.rejects(
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' }),
      /Injected appearance replacement failure/,
    )
    assert.ok(failed)
    assert.deepEqual(await snapshot(home), before)
    await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.transaction.json')), { code: 'ENOENT' })
    await assert.rejects(fs.stat(path.join(home, 'local/.shader-state.lock')), { code: 'ENOENT' })
  })

  it('serializes theme and shader changes from separate Node processes', async t => {
    const home = await fixture(t)
    await selectGhosttyShader({ home, shader: 'cubes' })
    const module = new URL('../asset/theme/template/ghostty/shader.mjs', import.meta.url).href
    const script = `
      const { applyGhosttyThemeAppearance, selectGhosttyShader } = await import(process.argv[1]);
      const home = process.argv[2];
      if (process.argv[3] === 'theme') {
        await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\\n' });
      } else {
        await selectGhosttyShader({ home, shader: 'neuro-noise' });
      }
    `
    const results = await Promise.allSettled(['theme', 'shader'].map(action =>
      execFileAsync(process.execPath, ['--input-type=module', '-e', script, module, home, action], { timeout: 10_000 }),
    ))
    for (const result of results) {
      assert.equal(result.status, 'fulfilled', result.status === 'rejected' ? String(result.reason) : '')
    }
    assert.equal(await read(home, 'local/appearance'), 'light\n')
    assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/light/neuro-noise.glsl\n`)
    await assertNoLegacy(home)
  })
})
