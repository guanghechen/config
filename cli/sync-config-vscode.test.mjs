import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, it, mock } from 'node:test'

import {
  composeKeybindings,
  formatKey,
  handleSyncConfigVscode,
  resolveDefaultVscodeKeybindingsPath,
  resolveVscodeKeybindingPlatform,
  resolveVscodeRuntimePlatform,
  resolveVscodeSettingsPath,
  sortKeybindings,
  syncVscodeKeybindings,
  syncVscodeSettings,
} from './sync-config-vscode.mjs'

const tempDirs = []

afterEach(() => {
  for (const tempDir of tempDirs.splice(0)) fs.rmSync(tempDir, { recursive: true })
})

function createTempDir() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-config-vscode-'))
  tempDirs.push(tempDir)
  return tempDir
}

/**
 * @param {Record<string, string>} [overrides]
 * @returns {Record<string, string>}
 */
function createCliEnv(overrides = {}) {
  /** @type {Record<string, string>} */
  const env = {}
  for (const name of ['PATH', 'SystemRoot', 'WINDIR', 'TMPDIR', 'TEMP', 'TMP']) {
    const value = process.env[name]
    if (value) env[name] = value
  }
  return { ...env, ...overrides }
}

describe('sync-config-vscode keybinding order', () => {
  it('normalizes modifier order', () => {
    assert.equal(formatKey('shift+ctrl+cmd+f10'), 'cmd+ctrl+shift+f10')
  })

  it('sorts keys alphabetically with natural numeric order', () => {
    const keybindings = [
      { key: 'f10', command: 'f10' },
      { key: 'cmd+a', command: 'a' },
      { key: 'f2', command: 'f2' },
      { key: 'cmd+0', command: 'zero' },
      { key: 'cmd+/', command: 'slash' },
      { key: 'f1', command: 'f1' },
    ]

    assert.deepEqual(sortKeybindings(keybindings).map(x => x.key), [
      'cmd+/',
      'cmd+0',
      'cmd+a',
      'f1',
      'f2',
      'f10',
    ])
  })

  it('keeps equal-key rules in low-to-high priority order', () => {
    const keybindings = [
      { key: 'cmd+k', command: 'specific-low', when: 'firstContext' },
      { key: 'cmd+k', command: 'fallback' },
      { key: 'cmd+k', command: 'specific-high', when: 'secondContext' },
    ]

    assert.deepEqual(sortKeybindings(keybindings).map(x => x.command), [
      'fallback',
      'specific-low',
      'specific-high',
    ])
  })

  it('puts removals first and terminal rebinds last for equal keys', () => {
    const keybindings = composeKeybindings(
      [
        { key: 'cmd+k', command: '-default.command' },
        { key: 'cmd+j', command: '-other-default.command' },
      ],
      [
        { key: 'cmd+k', command: 'fallback' },
        { key: 'cmd+k', command: 'contextual', when: 'editorFocus' },
      ],
      [{ key: 'cmd+k', command: 'terminal', when: 'terminalFocus' }],
    )

    assert.deepEqual(keybindings.map(x => x.command), [
      '-other-default.command',
      '-default.command',
      'fallback',
      'contextual',
      'terminal',
    ])
  })
})

describe('sync-config-vscode terminal sequences', () => {
  it('matches each platform tmux keymap for session navigation', () => {
    const root = path.join(import.meta.dirname, '../asset/app/vscode/keybinding')
    const osx = JSON.parse(fs.readFileSync(path.join(root, 'osx/rebind.json'), 'utf8'))
    const win = JSON.parse(fs.readFileSync(path.join(root, 'win/rebind.json'), 'utf8'))
    const sequence = (keybindings, key) => keybindings.find(x => x.key.toLowerCase() === key)?.args?.text

    assert.equal(sequence(osx, 'cmd+,'), '\u0001,')
    assert.equal(sequence(osx, 'cmd+.'), '\u0001.')
    assert.equal(sequence(win, 'alt+,'), '\u001b,')
    assert.equal(sequence(win, 'alt+.'), '\u001b.')
  })
})

describe('sync-config-vscode cross-platform keybindings', () => {
  it('maps supported platforms to available keybinding variants', () => {
    assert.equal(resolveVscodeKeybindingPlatform('nix'), undefined)
    assert.equal(resolveVscodeKeybindingPlatform('win'), 'win')
    assert.equal(resolveVscodeKeybindingPlatform('wsl'), 'win')
    assert.equal(resolveVscodeKeybindingPlatform('osx'), 'osx')
    assert.equal(resolveVscodeKeybindingPlatform('unknown'), undefined)
  })

  it('resolves the runtime platform from a validated override', () => {
    assert.equal(resolveVscodeRuntimePlatform('nix', 'unknown'), 'nix')
    assert.equal(resolveVscodeRuntimePlatform('win', 'unknown'), 'win')
    assert.equal(resolveVscodeRuntimePlatform('osx', 'unknown'), 'osx')
    assert.equal(resolveVscodeRuntimePlatform('wsl', 'unknown'), 'wsl')
    assert.equal(resolveVscodeRuntimePlatform('invalid', 'nix'), 'nix')
  })

  it('resolves default keybindings paths on every supported platform', () => {
    assert.equal(
      resolveDefaultVscodeKeybindingsPath('nix', {
        HOME: '/home/tester',
        XDG_CONFIG_HOME: '/home/tester/.xdg',
      }),
      undefined,
    )
    assert.equal(
      resolveDefaultVscodeKeybindingsPath('osx', { HOME: '/Users/tester' }),
      '/Users/tester/Library/Application Support/Code/User/keybindings.json',
    )
    assert.equal(
      resolveDefaultVscodeKeybindingsPath('win', {
        APPDATA: String.raw`C:\Users\tester\AppData\Roaming`,
      }),
      String.raw`C:\Users\tester\AppData\Roaming\Code\User\keybindings.json`,
    )
    assert.equal(
      resolveDefaultVscodeKeybindingsPath('wsl', { GHC_WINDOWS_USERNAME: 'tester' }),
      '/mnt/c/Users/tester/AppData/Roaming/Code/User/keybindings.json',
    )
  })

  it('syncs keybindings without crashing on every supported platform', () => {
    const tempDir = createTempDir()
    const targetPath = path.join(tempDir, 'keybindings.json')
    const writeFileSync = mock.method(fs, 'writeFileSync', () => {})

    try {
      assert.equal(syncVscodeKeybindings(targetPath, 'nix'), false)
      for (const platform of ['win', 'osx', 'wsl']) {
        assert.equal(syncVscodeKeybindings(targetPath, platform), true)
      }
    } finally {
      writeFileSync.mock.restore()
    }
  })

  it('navigates panel views with ctrl plus the platform modifier', () => {
    const root = path.join(import.meta.dirname, '../asset/app/vscode/keybinding')
    const osx = JSON.parse(fs.readFileSync(path.join(root, 'osx/customize.json'), 'utf8'))
    const win = JSON.parse(fs.readFileSync(path.join(root, 'win/customize.json'), 'utf8'))
    const find = (keybindings, key) => keybindings.find(x => x.key.toLowerCase() === key)
    const when =
      'panelFocus || (activePanel == workbench.view.extension.cspellPanel && !sideBarFocus && !auxiliaryBarFocus && (focusedView == cSpellIssuesViewByFile || focusedView == cSpellIssuesViewByIssue))'

    assert.deepEqual(find(osx, 'cmd+ctrl+,'), {
      key: 'cmd+ctrl+,',
      command: 'workbench.action.previousPanelView',
      when,
      title: 'panel: focus previous view',
    })
    assert.deepEqual(find(osx, 'cmd+ctrl+.'), {
      key: 'cmd+ctrl+.',
      command: 'workbench.action.nextPanelView',
      when,
      title: 'panel: focus next view',
    })
    assert.deepEqual(find(win, 'alt+ctrl+,'), {
      key: 'alt+ctrl+,',
      command: 'workbench.action.previousPanelView',
      when,
      title: 'panel: focus previous view',
    })
    assert.deepEqual(find(win, 'alt+ctrl+.'), {
      key: 'alt+ctrl+.',
      command: 'workbench.action.nextPanelView',
      when,
      title: 'panel: focus next view',
    })

    assert.equal(
      osx.some(x => x.command === 'workbench.action.previousPanelView' && x.key === 'cmd+['),
      false,
    )
    assert.equal(
      osx.some(x => x.command === 'workbench.action.nextPanelView' && x.key === 'cmd+]'),
      false,
    )
    assert.equal(
      win.some(x => x.command === 'workbench.action.previousPanelView' && x.key === 'alt+['),
      false,
    )
    assert.equal(
      win.some(x => x.command === 'workbench.action.nextPanelView' && x.key === 'alt+]'),
      false,
    )
  })

  it('toggles fullscreen from any focus context', () => {
    const root = path.join(import.meta.dirname, '../asset/app/vscode/keybinding')
    const osx = JSON.parse(fs.readFileSync(path.join(root, 'osx/customize.json'), 'utf8'))
    const win = JSON.parse(fs.readFileSync(path.join(root, 'win/customize.json'), 'utf8'))
    const find = (keybindings, key) => keybindings.find(x => x.key.toLowerCase() === key)

    assert.deepEqual(find(osx, 'cmd+ctrl+f11'), {
      key: 'cmd+ctrl+f11',
      command: 'workbench.action.toggleFullScreen',
    })
    assert.deepEqual(find(win, 'alt+ctrl+f11'), {
      key: 'alt+ctrl+f11',
      command: 'workbench.action.toggleFullScreen',
    })
  })
})

describe('sync-config-vscode CLI', () => {
  it('exits cleanly on every supported runtime platform when the target is unavailable', () => {
    const tempDir = createTempDir()
    const scriptPath = path.join(import.meta.dirname, 'sync-config-vscode.mjs')

    for (const platform of ['nix', 'win', 'osx', 'wsl']) {
      const targetPath = path.join(tempDir, platform, 'keybindings.json')
      const result = spawnSync(process.execPath, [scriptPath], {
        encoding: 'utf8',
        env: createCliEnv({
          GHC_ENV_PLATFORM: platform,
          f_vscode_keybindings: targetPath,
        }),
      })

      assert.equal(result.status, 0, `${platform}: ${result.stderr}`)
    }
  })

  it('performs no writes on Nix even when the target directory exists', () => {
    const tempDir = createTempDir()
    const targetPath = path.join(tempDir, 'keybindings.json')
    const result = spawnSync(
      process.execPath,
      [path.join(import.meta.dirname, 'sync-config-vscode.mjs'), targetPath],
      {
        encoding: 'utf8',
        env: createCliEnv({ GHC_ENV_PLATFORM: 'nix' }),
      },
    )

    assert.equal(result.status, 0, result.stderr)
    assert.equal(fs.existsSync(targetPath), false)
    assert.equal(fs.existsSync(path.join(tempDir, 'settings.json')), false)
  })
})

describe('sync-config-vscode settings', () => {
  it('resolves settings next to keybindings', () => {
    assert.equal(
      resolveVscodeSettingsPath('/code/User/keybindings.json'),
      path.join('/code/User', 'settings.json'),
    )
    assert.equal(resolveVscodeSettingsPath(undefined), undefined)
  })

  it('copies the canonical settings after validating them', () => {
    const tempDir = createTempDir()
    const sourcePath = path.join(tempDir, 'source.json')
    const targetPath = path.join(tempDir, 'settings.json')
    const sourceContent = '{\n  "editor.fontSize": 16\n}\n'

    fs.writeFileSync(sourcePath, sourceContent)
    fs.writeFileSync(targetPath, '{"local":true}\n')

    assert.equal(syncVscodeSettings(targetPath, sourcePath), true)
    assert.equal(fs.readFileSync(targetPath, 'utf8'), sourceContent)
  })

  it('syncs keybindings and sibling settings through the public handler', () => {
    const tempDir = createTempDir()
    const targetKeybindingsPath = path.join(tempDir, 'keybindings.json')
    const targetSettingsPath = path.join(tempDir, 'settings.json')
    const writes = new Map()
    const writeFileSync = mock.method(fs, 'writeFileSync', (filepath, content) => {
      writes.set(path.resolve(String(filepath)), content)
    })

    try {
      handleSyncConfigVscode(targetKeybindingsPath, 'win')
    } finally {
      writeFileSync.mock.restore()
    }

    assert.ok(writes.has(path.resolve(targetKeybindingsPath)))
    assert.equal(
      writes.get(path.resolve(targetSettingsPath)),
      fs.readFileSync(path.join(import.meta.dirname, '../asset/app/vscode/settings.json'), 'utf8'),
    )
  })

  it('skips settings when the target directory does not exist', () => {
    const tempDir = createTempDir()
    const sourcePath = path.join(tempDir, 'source.json')
    const targetPath = path.join(tempDir, 'missing', 'settings.json')

    fs.writeFileSync(sourcePath, '{}\n')

    assert.equal(syncVscodeSettings(targetPath, sourcePath), false)
    assert.equal(fs.existsSync(targetPath), false)
  })

  it('skips settings when the target parent is not a directory', () => {
    const tempDir = createTempDir()
    const parentPath = path.join(tempDir, 'not-a-directory')
    const sourcePath = path.join(tempDir, 'source.json')
    const targetPath = path.join(parentPath, 'settings.json')

    fs.writeFileSync(parentPath, '')
    fs.writeFileSync(sourcePath, '{}\n')

    assert.equal(syncVscodeSettings(targetPath, sourcePath), false)
    assert.equal(fs.existsSync(targetPath), false)
  })

  it('does not overwrite settings when the canonical source is invalid JSON', () => {
    const tempDir = createTempDir()
    const sourcePath = path.join(tempDir, 'source.json')
    const targetPath = path.join(tempDir, 'settings.json')
    const targetContent = '{"existing":true}\n'

    fs.writeFileSync(sourcePath, '{invalid}\n')
    fs.writeFileSync(targetPath, targetContent)

    assert.throws(() => syncVscodeSettings(targetPath, sourcePath), SyntaxError)
    assert.equal(fs.readFileSync(targetPath, 'utf8'), targetContent)
  })

  it('does not overwrite settings when the canonical source is not a JSON object', () => {
    const tempDir = createTempDir()
    const sourcePath = path.join(tempDir, 'source.json')
    const targetPath = path.join(tempDir, 'settings.json')
    const targetContent = '{"existing":true}\n'

    for (const sourceContent of ['null\n', '[]\n', '"text"\n']) {
      fs.writeFileSync(sourcePath, sourceContent)
      fs.writeFileSync(targetPath, targetContent)

      assert.throws(
        () => syncVscodeSettings(targetPath, sourcePath),
        /VSCode settings source must contain a JSON object/,
      )
      assert.equal(fs.readFileSync(targetPath, 'utf8'), targetContent)
    }
  })
})
