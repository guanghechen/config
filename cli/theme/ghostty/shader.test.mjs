import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import fsp from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, it } from 'node:test'

import {
  GHOSTTY_SHADERS,
  activateGhosttyShaderAppearance,
  applyGhosttyThemeAppearance,
  listGhosttyShaders,
  selectGhosttyShader,
  withGhosttyShaderStateLock,
} from './state.mjs'

const tempDirs = []

afterEach(() => {
  for (const tempDir of tempDirs.splice(0)) fs.rmSync(tempDir, { recursive: true })
})

function createHome() {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'ghostty-shader-'))
  tempDirs.push(home)
  fs.mkdirSync(path.join(home, 'local'))
  fs.mkdirSync(path.join(home, 'shaders'))
  return home
}

function createShader(home, shader) {
  fs.writeFileSync(path.join(home, 'shaders', `${shader}.glsl`), '')
}

function readLocal(home, filename) {
  return fs.readFileSync(path.join(home, 'local', filename), 'utf8')
}

describe('Ghostty shader state owner', () => {
  it('migrates a compatible legacy shader before activating its appearance', async () => {
    const home = createHome()
    const content = 'custom-shader = ../shaders/cubes-light.glsl\n'
    createShader(home, 'cubes-light')
    fs.writeFileSync(path.join(home, 'local/shader.conf'), content)

    await activateGhosttyShaderAppearance({ home, appearance: 'light' })

    assert.equal(readLocal(home, 'appearance'), 'light\n')
    assert.equal(readLocal(home, 'shader-light.conf'), content)
    assert.equal(readLocal(home, 'shader.conf'), content)
  })

  it('preserves a legacy shader for the other appearance', async () => {
    const home = createHome()
    const content = 'custom-shader = ../shaders/cubes.glsl\n'
    fs.writeFileSync(path.join(home, 'local/shader.conf'), content)

    await activateGhosttyShaderAppearance({ home, appearance: 'light' })

    assert.equal(readLocal(home, 'shader-dark.conf'), content)
    assert.equal(readLocal(home, 'shader-light.conf'), '')
    assert.equal(readLocal(home, 'shader.conf'), '')
    assert.equal(readLocal(home, 'appearance'), 'light\n')
  })

  it('refuses to overwrite an unrecognized legacy shader config', async () => {
    const home = createHome()
    const content = 'custom-shader = /tmp/custom.glsl\n'
    fs.writeFileSync(path.join(home, 'local/shader.conf'), content)

    await assert.rejects(
      activateGhosttyShaderAppearance({ home, appearance: 'dark' }),
      /Unrecognized Ghostty shader config/,
    )

    assert.equal(readLocal(home, 'shader.conf'), content)
    assert.equal(fs.existsSync(path.join(home, 'local/appearance')), false)
    assert.equal(fs.existsSync(path.join(home, 'local/shader-dark.conf')), false)
  })

  it('does not replace the theme when shader validation fails', async () => {
    const home = createHome()
    const themeContent = 'old theme\n'
    const shaderContent = 'custom-shader = /tmp/custom.glsl\n'
    fs.writeFileSync(path.join(home, 'local/theme.conf'), themeContent)
    fs.writeFileSync(path.join(home, 'local/shader.conf'), shaderContent)

    await assert.rejects(
      applyGhosttyThemeAppearance({
        home,
        appearance: 'light',
        themeContent: 'new theme\n',
      }),
      /Unrecognized Ghostty shader config/,
    )

    assert.equal(readLocal(home, 'theme.conf'), themeContent)
    assert.equal(readLocal(home, 'shader.conf'), shaderContent)
    assert.equal(fs.existsSync(path.join(home, 'local/appearance')), false)
  })

  it('lists and cycles only shaders available for the current appearance', async () => {
    const home = createHome()
    createShader(home, 'cubes')
    fs.writeFileSync(path.join(home, 'local/appearance'), 'dark\n')
    fs.writeFileSync(path.join(home, 'local/shader-dark.conf'), '')
    fs.writeFileSync(path.join(home, 'local/shader-light.conf'), '')
    fs.writeFileSync(path.join(home, 'local/shader.conf'), '')

    assert.deepEqual(await listGhosttyShaders({ home }), GHOSTTY_SHADERS.dark)

    const next = await selectGhosttyShader({ home })
    assert.deepEqual(next, { appearance: 'dark', shader: 'cubes' })
    assert.equal(
      readLocal(home, 'shader.conf'),
      'custom-shader = ../shaders/cubes.glsl\n',
    )

    const previous = await selectGhosttyShader({ home, previous: true })
    assert.deepEqual(previous, { appearance: 'dark', shader: 'off' })
    assert.equal(readLocal(home, 'shader.conf'), '')

    await assert.rejects(
      selectGhosttyShader({ home, shader: 'cubes-light' }),
      /not available for the dark appearance/,
    )
  })

  it('rejects an invalid explicit shader before migration mutates state', async () => {
    const home = createHome()
    const content = 'custom-shader = ../shaders/cubes-light.glsl\n'
    fs.writeFileSync(path.join(home, 'local/appearance'), 'light\n')
    fs.writeFileSync(path.join(home, 'local/shader.conf'), content)

    await assert.rejects(
      selectGhosttyShader({ home, shader: 'cubes' }),
      /not available for the light appearance/,
    )

    assert.equal(readLocal(home, 'shader.conf'), content)
    assert.equal(fs.existsSync(path.join(home, 'local/shader-dark.conf')), false)
    assert.equal(fs.existsSync(path.join(home, 'local/shader-light.conf')), false)
  })

  it('does not mutate saved state when active config cannot be read', async () => {
    const home = createHome()
    createShader(home, 'cubes')
    fs.writeFileSync(path.join(home, 'local/appearance'), 'dark\n')
    fs.writeFileSync(path.join(home, 'local/shader-dark.conf'), '')
    fs.writeFileSync(path.join(home, 'local/shader-light.conf'), '')
    fs.mkdirSync(path.join(home, 'local/shader.conf'))

    await assert.rejects(selectGhosttyShader({ home, shader: 'cubes' }))

    assert.equal(readLocal(home, 'shader-dark.conf'), '')
    assert.equal(fs.statSync(path.join(home, 'local/shader.conf')).isDirectory(), true)
  })

  it('does not mutate active config when appearance state cannot be read', async () => {
    const home = createHome()
    const darkContent = 'custom-shader = ../shaders/cubes.glsl\n'
    createShader(home, 'cubes')
    fs.writeFileSync(path.join(home, 'local/shader-dark.conf'), darkContent)
    fs.writeFileSync(path.join(home, 'local/shader-light.conf'), '')
    fs.writeFileSync(path.join(home, 'local/shader.conf'), '')
    fs.mkdirSync(path.join(home, 'local/appearance'))

    await assert.rejects(
      activateGhosttyShaderAppearance({ home, appearance: 'dark' }),
    )

    assert.equal(readLocal(home, 'shader.conf'), '')
    assert.equal(fs.statSync(path.join(home, 'local/appearance')).isDirectory(), true)
  })

  it('recovers a pending transaction before entering the next critical section', async () => {
    const home = createHome()
    const changedContent = 'custom-shader = ../shaders/cubes.glsl\n'
    fs.writeFileSync(path.join(home, 'local/appearance'), 'dark\n')
    fs.writeFileSync(path.join(home, 'local/shader-dark.conf'), changedContent)
    fs.writeFileSync(path.join(home, 'local/shader.conf'), '')
    fs.writeFileSync(
      path.join(home, 'local/.shader-state.transaction.json'),
      `${JSON.stringify({
        version: 1,
        files: [
          { target: 'saved-dark', existed: true, content: '' },
          { target: 'active', existed: true, content: '' },
        ],
      })}\n`,
    )

    await withGhosttyShaderStateLock(home, async () => {})

    assert.equal(readLocal(home, 'shader-dark.conf'), '')
    assert.equal(readLocal(home, 'shader.conf'), '')
    assert.equal(
      fs.existsSync(path.join(home, 'local/.shader-state.transaction.json')),
      false,
    )
  })

  it('recovers a pending theme and appearance transaction together', async () => {
    const home = createHome()
    fs.writeFileSync(path.join(home, 'local/theme.conf'), 'light theme\n')
    fs.writeFileSync(path.join(home, 'local/appearance'), 'light\n')
    fs.writeFileSync(path.join(home, 'local/shader.conf'), '')
    fs.writeFileSync(
      path.join(home, 'local/.shader-state.transaction.json'),
      `${JSON.stringify({
        version: 1,
        files: [
          { target: 'theme', existed: true, content: 'dark theme\n' },
          { target: 'active', existed: true, content: '' },
          { target: 'appearance', existed: true, content: 'dark\n' },
        ],
      })}\n`,
    )

    await withGhosttyShaderStateLock(home, async () => {})

    assert.equal(readLocal(home, 'theme.conf'), 'dark theme\n')
    assert.equal(readLocal(home, 'appearance'), 'dark\n')
    assert.equal(readLocal(home, 'shader.conf'), '')
  })

  it('serializes concurrent state mutations', async () => {
    const home = createHome()
    let releaseFirst
    let markFirstEntered
    const firstEntered = new Promise(resolve => {
      markFirstEntered = resolve
    })
    const firstGate = new Promise(resolve => {
      releaseFirst = resolve
    })

    const first = withGhosttyShaderStateLock(home, async () => {
      markFirstEntered()
      await firstGate
    })
    await firstEntered

    let secondEntered = false
    const second = withGhosttyShaderStateLock(home, async () => {
      secondEntered = true
    })

    await new Promise(resolve => setTimeout(resolve, 75))
    assert.equal(secondEntered, false)
    releaseFirst()
    await Promise.all([first, second])

    assert.equal(secondEntered, true)
    assert.equal(fs.existsSync(path.join(home, 'local/.shader-state.lock')), false)
  })

  it('publishes a complete lock record before exposing the lock path', async () => {
    const home = createHome()
    const originalLink = fsp.link
    let releaseFirstLink
    const firstLinkGate = new Promise(resolve => {
      releaseFirstLink = resolve
    })
    let markFirstLinkPublished
    const firstLinkPublished = new Promise(resolve => {
      markFirstLinkPublished = resolve
    })
    let delayed = false

    fsp.link = async (existingPath, newPath) => {
      const result = await originalLink(existingPath, newPath)
      if (!delayed && path.basename(newPath) === '.shader-state.lock') {
        delayed = true
        markFirstLinkPublished()
        await firstLinkGate
      }
      return result
    }

    try {
      const first = withGhosttyShaderStateLock(home, async () => {})
      await firstLinkPublished

      const lockPath = path.join(home, 'local/.shader-state.lock')
      assert.match(fs.readFileSync(lockPath, 'utf8'), /^\d+ [0-9a-f-]+\n$/)
      const old = new Date(Date.now() - 60_000)
      fs.utimesSync(lockPath, old, old)

      let secondEntered = false
      const second = withGhosttyShaderStateLock(home, async () => {
        secondEntered = true
      }, { staleMs: 0, timeoutMs: 1_000 })

      await new Promise(resolve => setTimeout(resolve, 75))
      assert.equal(secondEntered, false)
      releaseFirstLink()
      await Promise.all([first, second])
      assert.equal(secondEntered, true)
    } finally {
      fsp.link = originalLink
    }
  })

  it('recovers a lock left by a terminated process', async () => {
    const home = createHome()
    fs.writeFileSync(path.join(home, 'local/.shader-state.lock'), '2147483647 abandoned\n')

    let entered = false
    await withGhosttyShaderStateLock(home, async () => {
      entered = true
    }, { timeoutMs: 200 })

    assert.equal(entered, true)
    assert.equal(fs.existsSync(path.join(home, 'local/.shader-state.lock')), false)
  })

  it('requires manual cleanup after an interrupted stale-lock recovery', async () => {
    const home = createHome()
    fs.writeFileSync(
      path.join(home, 'local/.shader-state.lock'),
      '2147483647 abandoned\n',
    )
    fs.writeFileSync(
      path.join(home, 'local/.shader-state.recovery.lock'),
      '2147483647 abandoned\n',
    )

    await assert.rejects(
      withGhosttyShaderStateLock(home, async () => {}, { timeoutMs: 200 }),
      /Abandoned Ghostty shader recovery lock requires manual removal/,
    )

    assert.equal(
      fs.existsSync(path.join(home, 'local/.shader-state.recovery.lock')),
      true,
    )
    assert.equal(
      fs.existsSync(path.join(home, 'local/.shader-state.lock')),
      true,
    )
  })

  it('does not take over an abandoned recovery lock automatically', async () => {
    const home = createHome()
    fs.writeFileSync(
      path.join(home, 'local/.shader-state.recovery.lock'),
      '2147483647 abandoned\n',
    )

    let entered = false
    await assert.rejects(
      withGhosttyShaderStateLock(home, async () => {
        entered = true
      }, { timeoutMs: 200 }),
      /Abandoned Ghostty shader recovery lock requires manual removal/,
    )

    assert.equal(entered, false)
    assert.equal(
      fs.existsSync(path.join(home, 'local/.shader-state.recovery.lock')),
      true,
    )
  })

  it('keeps abandoned-lock contenders mutually exclusive', async () => {
    const home = createHome()
    fs.writeFileSync(path.join(home, 'local/.shader-state.lock'), '2147483647 abandoned\n')
    let active = 0
    let maximum = 0

    await Promise.all(
      Array.from({ length: 5 }, () => withGhosttyShaderStateLock(home, async () => {
        active += 1
        maximum = Math.max(maximum, active)
        await new Promise(resolve => setTimeout(resolve, 2))
        active -= 1
      }, { timeoutMs: 2_000 })),
    )

    assert.equal(maximum, 1)
  })

  it('keeps appearance and active config aligned after concurrent operations', async () => {
    const home = createHome()
    const darkContent = 'custom-shader = ../shaders/cubes.glsl\n'
    const lightContent = 'custom-shader = ../shaders/cubes-light.glsl\n'
    createShader(home, 'cubes')
    createShader(home, 'cubes-light')
    fs.writeFileSync(path.join(home, 'local/appearance'), 'dark\n')
    fs.writeFileSync(path.join(home, 'local/shader-dark.conf'), darkContent)
    fs.writeFileSync(path.join(home, 'local/shader-light.conf'), lightContent)
    fs.writeFileSync(path.join(home, 'local/shader.conf'), darkContent)

    await Promise.all([
      activateGhosttyShaderAppearance({ home, appearance: 'light' }),
      selectGhosttyShader({ home, shader: 'off' }),
      activateGhosttyShaderAppearance({ home, appearance: 'dark' }),
      selectGhosttyShader({ home, shader: 'off' }),
    ])

    const appearance = readLocal(home, 'appearance').trim()
    assert.equal(readLocal(home, 'shader.conf'), readLocal(home, `shader-${appearance}.conf`))
  })

  it('keeps the rendered theme and appearance aligned after concurrent applies', async () => {
    const home = createHome()

    await Promise.all(
      Array.from({ length: 12 }, (_, index) => {
        const appearance = index % 2 === 0 ? 'dark' : 'light'
        return applyGhosttyThemeAppearance({
          home,
          appearance,
          themeContent: `${appearance}\n`,
        })
      }),
    )

    const appearance = readLocal(home, 'appearance').trim()
    assert.equal(readLocal(home, 'theme.conf'), `${appearance}\n`)
  })
})

describe('Ghostty shader CLI', () => {
  it('reloads managed config without requiring the Ghostty executable in PATH', {
    skip: process.platform === 'win32',
  }, () => {
    const home = createHome()
    const localDir = path.join(home, 'local')
    const binDir = path.join(home, 'bin')
    const pkillArgsPath = path.join(home, 'pkill-args')
    fs.mkdirSync(binDir)
    fs.writeFileSync(path.join(home, '.git'), 'gitdir: test\n')
    fs.writeFileSync(path.join(localDir, 'appearance'), 'dark\n')
    fs.writeFileSync(path.join(localDir, 'shader-dark.conf'), '')
    fs.writeFileSync(path.join(localDir, 'shader-light.conf'), '')
    fs.writeFileSync(path.join(localDir, 'shader.conf'), '')
    createShader(home, 'cubes')

    const pkillPath = path.join(binDir, 'pkill')
    fs.writeFileSync(
      pkillPath,
      '#!/bin/sh\nprintf "%s\\n" "$@" > "$GHC_TEST_PKILL_ARGS"\n',
    )
    fs.chmodSync(pkillPath, 0o755)

    const moduleUrl = new URL('./shader.mjs', import.meta.url).href
    const invoke = shader => spawnSync(
      process.execPath,
      [
        '--input-type=module',
        '--eval',
        `import { handleGhosttyShader } from ${JSON.stringify(moduleUrl)}
const reporter = { debug() {}, info() {}, warn() {}, error() {} }
await handleGhosttyShader(reporter, process.env.GHC_TEST_GHOSTTY_HOME, {}, process.env.GHC_TEST_SHADER || undefined)`,
      ],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          GHC_TEST_GHOSTTY_HOME: home,
          GHC_TEST_PKILL_ARGS: pkillArgsPath,
          GHC_TEST_SHADER: shader ?? '',
          PATH: binDir,
        },
      },
    )

    const result = invoke()

    assert.equal(result.status, 0, result.stderr)
    assert.equal(fs.readFileSync(pkillArgsPath, 'utf8'), '-USR2\n-x\nghostty\n')
    assert.equal(
      fs.readFileSync(path.join(localDir, 'shader.conf'), 'utf8'),
      'custom-shader = ../shaders/cubes.glsl\n',
    )

    fs.rmSync(path.join(home, '.git'))
    fs.rmSync(pkillArgsPath)
    const unmanagedResult = invoke('off')

    assert.equal(unmanagedResult.status, 0, unmanagedResult.stderr)
    assert.equal(fs.existsSync(pkillArgsPath), false)
  })
})
