import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import {
  CODEX_CONFIG_DIR,
  F_WINDOWS_TERMINAL_SETTINGS,
  XDG_CONFIG_HOME,
} from '#env'
import { signal_process } from '#util/command'

import {
  apps,
  create_theme_apps,
  evaluate_theme_app_condition,
  load_theme_app_definitions,
} from './_config.mjs'

function createFixture(root, name, definition, withDefault = true) {
  const appDir = path.join(root, name)
  fs.mkdirSync(appDir, { recursive: true })
  fs.writeFileSync(
    path.join(appDir, 'meta.mjs'),
    `export default ${JSON.stringify(definition, null, 2)}\n`,
  )
  if (withDefault) fs.writeFileSync(path.join(appDir, 'default.hbs'), 'theme')
}

describe('theme app definitions', () => {
  it('loads every configured app in stable name order', async () => {
    const definitions = await load_theme_app_definitions()

    assert.deepEqual(
      definitions.map(app => app.name),
      [
        'alacritty',
        'bat',
        'btop',
        'codex',
        'fzf',
        'gemini',
        'ghostty',
        'git-delta',
        'herdr',
        'kitty',
        'lazygit',
        'newsboat',
        'nvim',
        'nvim-nvchad',
        'opencode',
        'tmux',
        'wezterm',
        'windows-terminal',
        'yazi',
        'yui',
      ],
    )
    const lifecycleFields = [
      'on_render',
      'on_prepare',
      'on_apply',
      'on_after_apply',
      'on_after_gen',
    ]
    assert.deepEqual(
      Object.fromEntries(
        definitions
          .map(app => [
            app.name,
            lifecycleFields.filter(field => typeof app[field] === 'function'),
          ])
          .filter(([, fields]) => fields.length > 0),
      ),
      {
        alacritty: ['on_after_apply'],
        bat: ['on_after_apply', 'on_after_gen'],
        btop: ['on_after_apply'],
        gemini: ['on_after_apply'],
        ghostty: ['on_prepare', 'on_apply', 'on_after_apply'],
        herdr: ['on_after_apply'],
        kitty: ['on_after_apply'],
        nvim: ['on_after_apply'],
        'nvim-nvchad': ['on_after_apply'],
        tmux: ['on_after_apply'],
        wezterm: ['on_after_apply'],
        'windows-terminal': ['on_render'],
        yui: ['on_after_apply'],
      },
    )

    const byName = Object.fromEntries(definitions.map(app => [app.name, app]))
    const windowsTerminalSettingsPath = F_WINDOWS_TERMINAL_SETTINGS
      ? path.resolve(F_WINDOWS_TERMINAL_SETTINGS)
      : null
    assert.deepEqual(
      {
        codex: [byName.codex.location, byName.codex.extname],
        fzf: [byName.fzf.themes, byName.fzf.local],
        ghostty: [byName.ghostty.extname, byName.ghostty.local],
        herdr: byName.herdr.active,
        nvim: [byName.nvim.themes, byName.nvim.local],
        windowsTerminal: [
          byName['windows-terminal'].location,
          byName['windows-terminal'].themes,
          byName['windows-terminal'].local,
        ],
      },
      {
        codex: [CODEX_CONFIG_DIR, '-ghc.tmTheme'],
        fzf: [null, 'fzf.fzfrc'],
        ghostty: ['', 'local/theme.conf'],
        herdr: {
          all: [
            { file: 'config.shared.toml' },
            { file: 'script/sync.mjs' },
          ],
        },
        nvim: ['lua/dot/theme/scheme/', null],
        windowsTerminal: [
          windowsTerminalSettingsPath
            ? path.dirname(windowsTerminalSettingsPath)
            : XDG_CONFIG_HOME,
          null,
          windowsTerminalSettingsPath,
        ],
      },
    )
  })

  it('accepts direct module values and absolute local paths', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-meta-'))
    const location = path.join(root, 'demo')
    const local = path.join(root, 'settings.json')

    try {
      createFixture(root, 'demo', {
        location,
        active: { directory: '.' },
        themes: 'themes/',
        extname: '.json',
        local,
      })

      assert.deepEqual(
        await load_theme_app_definitions(root),
        [{
          name: 'demo',
          location,
          active: { directory: '.' },
          themes: 'themes/',
          extname: '.json',
          local,
        }],
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('normalizes optional Windows Terminal settings paths', () => {
    const script = [
      'import { apps } from "./cli/theme/_config.mjs"',
      'const app = apps.find(app => app.name === "windows-terminal")',
      'process.stdout.write(JSON.stringify({ location: app.home, local: app.local }))',
    ].join(';')
    const loadWindowsTerminal = value => JSON.parse(execFileSync(
      process.execPath,
      ['--input-type=module', '-e', script],
      {
        cwd: process.cwd(),
        encoding: 'utf8',
        env: { ...process.env, f_windows_terminal_settings: value },
      },
    ))

    assert.deepEqual(loadWindowsTerminal(''), {
      location: XDG_CONFIG_HOME,
      local: null,
    })

    const relativePath = 'tmp/windows-terminal-settings.json'
    const settingsPath = path.resolve(relativePath)
    assert.deepEqual(loadWindowsTerminal(relativePath), {
      location: path.dirname(settingsPath),
      local: settingsPath,
    })
  })

  it('rejects incomplete, unknown, and unsafe definitions', async t => {
    const cases = [
      {
        name: 'missing field',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
        },
        error: /Missing required theme app definition field "local"/,
      },
      {
        name: 'unknown field',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
          local: null,
          command: 'reload',
        },
        error: /Unknown field in theme app definition for demo: command/,
      },
      {
        name: 'path traversal',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: '../themes',
          extname: '',
          local: null,
        },
        error: /must be relative without traversal/,
      },
      {
        name: 'ambiguous active condition',
        definition: {
          location: '/tmp/demo',
          active: { file: 'config', directory: '.' },
          themes: null,
          extname: '',
          local: null,
        },
        error: /condition must contain exactly one predicate/,
      },
      {
        name: 'legacy hooks field',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
          local: null,
          hooks: {},
        },
        error: /Unknown field in theme app definition for demo: hooks/,
      },
      {
        name: 'invalid lifecycle function',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
          local: null,
          on_apply: 'write',
        },
        error: /lifecycle field "on_apply" must be a function/,
      },
      {
        name: 'unsafe extname',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: 'themes/',
          extname: '/../../outside',
          local: null,
        },
        error: /extname must be a path-free string/,
      },
      {
        name: 'relative location',
        definition: {
          location: 'relative/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
          local: null,
        },
        error: /location must be a non-empty absolute path/,
      },
      {
        name: 'unsafe local path',
        definition: {
          location: '/tmp/demo',
          active: { directory: '.' },
          themes: null,
          extname: '',
          local: '../settings.json',
        },
        error: /must be relative without traversal/,
      },
    ]

    for (const testCase of cases) {
      await t.test(testCase.name, async () => {
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-meta-'))
        try {
          createFixture(root, 'demo', testCase.definition)
          await assert.rejects(
            load_theme_app_definitions(root),
            testCase.error,
          )
        } finally {
          fs.rmSync(root, { recursive: true, force: true })
        }
      })
    }
  })

  it('requires both a definition and a default template for every app directory', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-meta-'))

    try {
      createFixture(root, 'demo', {
        location: '/tmp/demo',
        active: { directory: '.' },
        themes: null,
        extname: '',
        local: null,
      }, false)
      await assert.rejects(
        load_theme_app_definitions(root),
        /Missing default template for theme app: demo/,
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('reports invalid definition modules with their path', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-meta-'))
    const appDir = path.join(root, 'demo')

    try {
      fs.mkdirSync(appDir, { recursive: true })
      fs.writeFileSync(path.join(appDir, 'meta.mjs'), 'export default {')
      fs.writeFileSync(path.join(appDir, 'default.hbs'), 'theme')
      await assert.rejects(
        load_theme_app_definitions(root),
        error => {
          assert.match(error.message, /Invalid theme app definition module:/)
          assert.match(error.message, /demo\/meta\.mjs$/)
          return true
        },
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('composes definitions with default and app-defined lifecycle functions', () => {
    const byName = Object.fromEntries(apps.map(app => [app.name, app]))

    assert.equal(typeof byName.codex.active, 'function')
    assert.equal(typeof byName.codex.render, 'function')
    assert.equal(byName.codex.after_apply, undefined)
    assert.equal(typeof byName.bat.after_apply, 'function')
    assert.equal(typeof byName.bat.after_gen, 'function')
    assert.equal(typeof byName.btop.after_apply, 'function')
    assert.equal(typeof byName.ghostty.prepare, 'function')
    assert.equal(typeof byName.ghostty.apply, 'function')
    assert.equal(typeof byName.ghostty.after_apply, 'function')
    assert.equal(typeof byName.nvim.after_apply, 'function')
    assert.equal(typeof byName['nvim-nvchad'].after_apply, 'function')
    assert.equal(typeof byName.tmux.after_apply, 'function')
    assert.equal(typeof byName['windows-terminal'].active, 'function')
    assert.equal(typeof byName['windows-terminal'].render, 'function')
    assert.equal(typeof byName.yui.after_apply, 'function')
  })

  it('preserves the active Bat theme on apply', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-bat-'))
    const bat = apps.find(app => app.name === 'bat')

    try {
      assert.ok(bat?.after_apply)
      await bat.after_apply(
        /** @type {never} */ ({ ...bat, home: root }),
        /** @type {never} */ ({ theme: 'rosepine', variant: 'main' }),
        /** @type {never} */ ({}),
      )
      assert.equal(fs.readFileSync(path.join(root, 'config'), 'utf8'), '--theme=rosepine-main')
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('maps lifecycle functions without a behavior registry', () => {
    const onRender = async () => 'custom'
    const onAfterApply = async () => {}
    const [app] = create_theme_apps(
      [{
        name: 'demo',
        location: '/tmp/demo',
        active: { directory: '.' },
        themes: null,
        extname: '',
        local: null,
        on_render: onRender,
        on_after_apply: onAfterApply,
      }],
    )

    assert.equal(app.render, onRender)
    assert.equal(app.after_apply, onAfterApply)
  })
})

describe('theme app conditions', () => {
  it('evaluates env, file, directory, and all predicates', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-condition-'))
    const app = /** @type {never} */ ({ home: root, local: 'local/theme.conf' })

    try {
      fs.mkdirSync(path.join(root, 'local'), { recursive: true })
      fs.writeFileSync(path.join(root, 'local/theme.conf'), 'theme')

      assert.equal(evaluate_theme_app_condition({ env: 'TMUX' }, app, {}), false)
      assert.equal(evaluate_theme_app_condition({ env: 'toString' }, app, {}), false)
      assert.equal(
        evaluate_theme_app_condition({ env: 'TMUX' }, app, { TMUX: '/tmp/tmux' }),
        true,
      )
      assert.equal(evaluate_theme_app_condition({ directory: '.' }, app), true)
      assert.equal(evaluate_theme_app_condition({ file: '${local}' }, app), true)
      assert.equal(
        evaluate_theme_app_condition({
          all: [
            { directory: 'local' },
            { file: 'local/theme.conf' },
          ],
        }, app),
        true,
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('treats an unavailable local target as inactive', () => {
    const app = /** @type {never} */ ({ home: '/tmp/demo', local: null })
    assert.equal(evaluate_theme_app_condition({ file: '${local}' }, app), false)
  })
})

describe('theme process signals', () => {
  it('sends an exact process signal on Unix', async () => {
    const { reporter, warnings } = createReporter()
    const calls = []

    await signal_process(reporter, 'SIGUSR2', 'demo', {
      platform: 'nix',
      execute: async params => {
        calls.push(params)
        return { stdout: '', stderr: '', code: 0 }
      },
    })

    assert.deepEqual(calls.map(({ cmd, args, silent }) => ({ cmd, args, silent })), [{
      cmd: 'pkill',
      args: ['-USR2', '-x', 'demo'],
      silent: true,
    }])
    assert.deepEqual(warnings, [])
  })

  it('skips Windows and propagates no matching process errors', async () => {
    const { reporter, warnings } = createReporter()
    const calls = []
    const execute = async () => {
      calls.push('execute')
      throw Object.assign(new Error('no match'), { code: 1 })
    }

    await signal_process(reporter, 'SIGUSR2', 'demo', {
      platform: 'win',
      execute,
    })
    await assert.rejects(
      signal_process(reporter, 'SIGUSR2', 'demo', {
        platform: 'nix',
        execute,
      }),
      /no match/,
    )

    assert.deepEqual(calls, ['execute'])
    assert.deepEqual(warnings, [])
  })

  it('propagates process signaling failures', async () => {
    const { reporter, warnings } = createReporter()

    await assert.rejects(
      signal_process(reporter, 'SIGUSR1', 'demo', {
        platform: 'nix',
        execute: async () => { throw new Error('pkill unavailable') },
      }),
      /pkill unavailable/,
    )

    assert.deepEqual(warnings, [])
  })
})

function createReporter() {
  const warnings = []
  return {
    warnings,
    reporter: {
      debug() {},
      info() {},
      warn(...args) { warnings.push(args) },
      error() {},
    },
  }
}
