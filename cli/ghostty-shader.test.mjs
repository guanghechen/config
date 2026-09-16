import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { promisify } from 'node:util'

import { XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR } from '#env'

import { handleGhosttyShader } from './ghostty-shader.mjs'

import {
  GHOSTTY_SHADERS,
  applyGhosttyThemeAppearance,
  selectGhosttyShader,
  validateGhosttyThemeAppearance,
} from '../asset/theme/template/ghostty/shader.mjs'

const shaderNames = [
  'off', 'cubes', 'fireworks-rockets', 'gears-and-belts', 'inside-the-matrix',
  'matrix-hallway', 'mnoise', 'neuro-noise', 'sparks-from-fire', 'starfield',
]
const legacyFiles = [
  'local/shader',
  'local/.shader-state.transaction.json', 'local/.shader-state.recovery.lock',
  'local/shader-dark.conf', 'local/shader-light.conf', 'theme-dark.conf', 'theme-light.conf',
]
const stateFiles = [
  'local/theme.conf', 'local/shader.conf', 'local/appearance', ...legacyFiles,
]
const wallpaperConfig = `background-image = ${path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.png')}\n`
const lightWallpaperConfig = `background-image = ${path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Barrett-Girl.png')}\n`
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
  it('lists shaders without reading or creating Ghostty state', async t => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'ghostty-list-test-'))
    t.after(() => fs.rm(root, { recursive: true, force: true }))
    const home = path.join(root, 'unconfigured')
    const output = []
    const write = t.mock.method(process.stdout, 'write', chunk => {
      output.push(String(chunk))
      return true
    })
    try {
      await handleGhosttyShader(/** @type {never} */ ({}), home, { list: true }, undefined)
    } finally {
      write.mock.restore()
    }
    assert.equal(output.join(''), `${shaderNames.join('\n')}\n`)
    await assert.rejects(fs.stat(home), { code: 'ENOENT' })
  })

  it('leaves an existing lock untouched when waiting times out', async t => {
    const home = await fixture(t)
    const lock = 'interrupted command\n'
    await fs.writeFile(path.join(home, 'local/.shader-state.lock'), lock)
    const before = await snapshot(home)
    let now = 0
    t.mock.method(Date, 'now', () => { now += 5_001; return now })
    await assert.rejects(selectGhosttyShader({ home, shader: 'cubes' }), /Timed out waiting for Ghostty state lock/)
    assert.deepEqual(await snapshot(home), before)
    assert.equal(await read(home, 'local/.shader-state.lock'), lock)
  })

  it('keeps the old shader file when atomic replacement fails', async t => {
    const home = await fixture(t)
    const before = await snapshot(home)
    const rename = fs.rename
    t.mock.method(fs, 'rename', async (source, destination) => {
      if (destination === path.join(home, 'local/shader.conf')) {
        throw Object.assign(new Error('Injected shader replacement failure'), { code: 'EIO' })
      }
      return rename(source, destination)
    })
    await assert.rejects(selectGhosttyShader({ home, shader: 'cubes' }), /Injected shader replacement failure/)
    assert.deepEqual(await snapshot(home), before)
    assert.deepEqual((await fs.readdir(path.join(home, 'local'))).sort(), ['appearance', 'shader.conf', 'theme.conf'])
  })

  for (const appearance of /** @type {const} */ (['dark', 'light'])) {
    it(`stores every ${appearance} selection only in shader.conf`, async t => {
      const home = await fixture(t, appearance)
      assert.deepEqual(GHOSTTY_SHADERS, shaderNames)
      for (const shader of shaderNames) {
        assert.deepEqual(await selectGhosttyShader({ home, shader }), { appearance, shader })
        const active = shader === 'off'
          ? appearance === 'dark' ? wallpaperConfig : lightWallpaperConfig
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

  it('switches wallpapers with appearance while keeping the shader off', async t => {
    const home = await fixture(t)
    await fs.writeFile(path.join(home, 'shader.conf'), 'custom-shader = shaders/cursor.glsl\n')
    await selectGhosttyShader({ home, shader: 'off' })
    assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'light theme\n' })
    await assertNoLegacy(home)
    assert.equal(await read(home, 'local/shader.conf'), lightWallpaperConfig)
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
    'custom-shader = ../shaders/dark/starfield.glsl\n',
    'background-image = /tmp/custom.png\n',
    `${wallpaperConfig}custom-shader = /tmp/custom.glsl\n`,
    'background-image =\ncustom-shader = /tmp/custom.glsl\n',
    'custom-shader = shaders/cubes-light.glsl\n',
    'background-image =\nbackground-opacity = 1\n',
    'background-image =\ncustom-shader = ../shaders/light/../../cursor.glsl\n',
    'background-image =\ncustom-shader = ../shaders/dark/unknown.glsl\n',
    'background-image =\ncustom-shader = ../shaders/dark/off.glsl\n',
  ]) {
    it(`deletes an unrecognized active background and defaults to off: ${content.trim()}`, async t => {
      const home = await fixture(t)
      await fs.writeFile(path.join(home, 'local/shader.conf'), content)
      const before = await snapshot(home)
      assert.deepEqual(await validateGhosttyThemeAppearance({ home, appearance: 'light' }), {
        appearance: 'light', shader: 'off',
      })
      assert.deepEqual(await snapshot(home), before.map((value, index) => index === 1 ? undefined : value))
      await applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' })
      assert.equal(await read(home, 'local/shader.conf'), lightWallpaperConfig)

      await fs.writeFile(path.join(home, 'local/shader.conf'), content)
      await applyGhosttyThemeAppearance({ home, appearance: 'dark', themeContent: 'new theme\n' })
      assert.equal(await read(home, 'local/shader.conf'), wallpaperConfig)
    })
  }

  it('allows selecting and cycling shaders after deleting unrecognized state', async t => {
    const home = await fixture(t)
    for (const [options, shader] of /** @type {const} */ ([
      [{ shader: 'starfield' }, 'starfield'],
      [{ next: true }, 'cubes'],
      [{ previous: true }, 'starfield'],
    ])) {
      await fs.writeFile(path.join(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/starfield.glsl\n')
      assert.deepEqual(await selectGhosttyShader({ home, ...options }), { appearance: 'dark', shader })
      assert.equal(await read(home, 'local/shader.conf'), `${noWallpaperConfig}custom-shader = ../shaders/dark/${shader}.glsl\n`)
    }
  })

  it('propagates errors reading the active config without deleting it', async t => {
    const home = await fixture(t)
    await fs.unlink(path.join(home, 'local/shader.conf'))
    await fs.mkdir(path.join(home, 'local/shader.conf'))
    await assert.rejects(validateGhosttyThemeAppearance({ home, appearance: 'dark' }), { code: 'EISDIR' })
    assert.ok((await fs.stat(path.join(home, 'local/shader.conf'))).isDirectory())
  })

  it('propagates errors deleting unrecognized state without applying the theme', async t => {
    const home = await fixture(t)
    await fs.writeFile(path.join(home, 'local/shader.conf'), 'custom-shader = ../shaders/dark/starfield.glsl\n')
    const before = await snapshot(home)
    const unlink = fs.unlink
    t.mock.method(fs, 'unlink', async filepath => {
      if (filepath === path.join(home, 'local/shader.conf')) {
        throw Object.assign(new Error('Injected shader deletion failure'), { code: 'EACCES' })
      }
      return unlink(filepath)
    })
    await assert.rejects(
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }),
      { code: 'EACCES' },
    )
    assert.deepEqual(await snapshot(home), before)
  })

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

  it('removes newly created files when a later theme replacement fails', async t => {
    const home = await fixture(t)
    await fs.unlink(path.join(home, 'local/theme.conf'))
    await fs.unlink(path.join(home, 'local/shader.conf'))
    const before = await snapshot(home)
    const rename = fs.rename
    t.mock.method(fs, 'rename', async (source, destination) => {
      if (destination === path.join(home, 'local/appearance')) {
        throw Object.assign(new Error('Injected appearance replacement failure'), { code: 'EIO' })
      }
      return rename(source, destination)
    })
    await assert.rejects(
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }),
      /Injected appearance replacement failure/,
    )
    assert.deepEqual(await snapshot(home), before)
    assert.deepEqual(await fs.readdir(path.join(home, 'local')), ['appearance'])
  })

  it('reports rollback failures and still restores the other changed files', async t => {
    const home = await fixture(t)
    const before = await snapshot(home)
    const rename = fs.rename
    let themeReplacements = 0
    t.mock.method(fs, 'rename', async (source, destination) => {
      if (destination === path.join(home, 'local/appearance')) {
        throw new Error('Injected appearance replacement failure')
      }
      if (destination === path.join(home, 'local/theme.conf') && ++themeReplacements === 2) {
        throw new Error('Injected theme rollback failure')
      }
      return rename(source, destination)
    })
    await assert.rejects(
      applyGhosttyThemeAppearance({ home, appearance: 'light', themeContent: 'new theme\n' }),
      error => {
        assert.ok(error instanceof AggregateError)
        assert.deepEqual(error.errors.map(item => item.message), [
          'Injected appearance replacement failure', 'Injected theme rollback failure',
        ])
        return true
      },
    )
    assert.equal(await read(home, 'local/theme.conf'), 'new theme\n')
    assert.equal(await read(home, 'local/shader.conf'), before[1])
    assert.equal(await read(home, 'local/appearance'), before[2])
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
