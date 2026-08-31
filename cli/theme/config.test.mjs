import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import { XDG_CONFIG_HOME } from '#env'
import { signal_process } from '#util/command'

import {
  apps,
  evaluate_theme_app_condition,
  load_theme_app_definitions,
} from './config.mjs'

const reporter = {
  debug() {},
  info() {},
  warn() {},
  error() {},
}
const baseDefinition = {
  location: '/tmp/demo',
  active: { directory: '.' },
  themes: null,
  extname: '',
  local: null,
}

function createFixture(root, definition) {
  const appDir = path.join(root, 'demo')
  fs.mkdirSync(appDir, { recursive: true })
  fs.writeFileSync(
    path.join(appDir, 'meta.mjs'),
    `export default ${JSON.stringify(definition, null, 2)}\n`,
  )
  fs.writeFileSync(path.join(appDir, 'default.hbs'), 'theme')
}

describe('theme app config', () => {
  it('loads real definitions and preserves critical lifecycle wiring', async () => {
    const definitions = await load_theme_app_definitions()
    const names = definitions.map(definition => definition.name)
    const byName = Object.fromEntries(apps.map(app => [app.name, app]))

    assert.equal(definitions.length, apps.length)
    assert.deepEqual(names, names.toSorted())
    assert.equal(typeof byName.bat.after_apply, 'function')
    assert.equal(typeof byName.ghostty.prepare, 'function')
    assert.equal(typeof byName.ghostty.apply, 'function')
    assert.equal(typeof byName['windows-terminal'].render, 'function')
  })

  it('normalizes optional Windows Terminal settings paths', () => {
    const script = [
      'import { apps } from "./cli/theme/config.mjs"',
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

    const settingsPath = path.resolve('tmp/windows-terminal-settings.json')
    assert.deepEqual(loadWindowsTerminal('tmp/windows-terminal-settings.json'), {
      location: path.dirname(settingsPath),
      local: settingsPath,
    })
  })

  it('rejects unsafe or malformed definitions', async t => {
    const cases = [
      [{ ...baseDefinition, command: 'reload' }, /Unknown field/],
      [{ ...baseDefinition, themes: '../themes' }, /relative without traversal/],
      [
        { ...baseDefinition, active: { file: 'config', directory: '.' } },
        /exactly one predicate/,
      ],
      [{ ...baseDefinition, on_apply: 'write' }, /must be a function/],
      [
        {
          location: baseDefinition.location,
          active: baseDefinition.active,
          themes: baseDefinition.themes,
          extname: baseDefinition.extname,
        },
        /Missing required theme app definition field "local"/,
      ],
    ]

    for (const [definition, error] of cases) {
      await t.test(error.source, async () => {
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-config-'))
        try {
          createFixture(root, definition)
          await assert.rejects(load_theme_app_definitions(root), error)
        } finally {
          fs.rmSync(root, { recursive: true, force: true })
        }
      })
    }
  })

  it('preserves the active Bat theme on apply', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-bat-'))
    const bat = apps.find(app => app.name === 'bat')

    try {
      assert.ok(bat?.after_apply)
      await bat.after_apply(
        /** @type {never} */ ({ ...bat, home: root }),
        /** @type {never} */ ({ theme: 'rosepine', variant: 'main' }),
        /** @type {never} */ (reporter),
      )
      assert.equal(fs.readFileSync(path.join(root, 'config'), 'utf8'), '--theme=rosepine-main')
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })
})

describe('theme app conditions', () => {
  it('evaluates declared predicates without inherited env values', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-condition-'))
    const app = /** @type {never} */ ({ home: root, local: 'local/theme.conf' })

    try {
      fs.mkdirSync(path.join(root, 'local'), { recursive: true })
      fs.writeFileSync(path.join(root, 'local/theme.conf'), 'theme')

      assert.equal(evaluate_theme_app_condition({ env: 'toString' }, app, {}), false)
      assert.equal(
        evaluate_theme_app_condition({ env: 'TMUX' }, app, { TMUX: '/tmp/tmux' }),
        true,
      )
      assert.equal(evaluate_theme_app_condition({ file: '${local}' }, app), true)
      assert.equal(evaluate_theme_app_condition({
        all: [{ directory: 'local' }, { file: 'local/theme.conf' }],
      }, app), true)
      assert.equal(
        evaluate_theme_app_condition(
          { file: '${local}' },
          /** @type {never} */ ({ home: root, local: null }),
        ),
        false,
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })
})

describe('theme process signals', () => {
  it('uses exact Unix signaling and preserves failure semantics', async () => {
    const calls = []
    const execute = async params => {
      calls.push(params)
      return { stdout: '', stderr: '', code: 0 }
    }

    await signal_process(reporter, 'SIGUSR2', 'demo', { platform: 'nix', execute })
    await signal_process(reporter, 'SIGUSR2', 'demo', { platform: 'win', execute })

    assert.deepEqual(calls.map(({ cmd, args, silent }) => ({ cmd, args, silent })), [{
      cmd: 'pkill',
      args: ['-USR2', '-x', 'demo'],
      silent: true,
    }])
    await assert.rejects(
      signal_process(reporter, 'SIGUSR1', 'demo', {
        platform: 'nix',
        execute: async () => { throw new Error('pkill unavailable') },
      }),
      /pkill unavailable/,
    )
  })
})
