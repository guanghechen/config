import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import { applyThemeToApps, resolveThemeToggle } from './theme.mjs'
import { apps } from './theme/_config.mjs'

function createReporter() {
  const errors = []
  return {
    errors,
    reporter: {
      debug() {},
      info() {},
      warn() {},
      error(...args) {
        errors.push(args)
      },
    },
  }
}

function createSchemeLoader() {
  const schemes = {
    'catppuccin-latte': {
      theme: 'catppuccin',
      variant: 'latte',
      opposite: 'frappe',
      darken: false,
    },
    'catppuccin-frappe': {
      theme: 'catppuccin',
      variant: 'frappe',
      opposite: 'mocha',
      darken: true,
    },
    'catppuccin-mocha': {
      theme: 'catppuccin',
      variant: 'mocha',
      opposite: 'macchiato',
      darken: true,
    },
    'catppuccin-macchiato': {
      theme: 'catppuccin',
      variant: 'macchiato',
      opposite: 'latte',
      darken: true,
    },
    standalone: {
      theme: 'standalone',
      variant: '',
      opposite: '',
      darken: true,
    },
  }
  return async (reporter, theme) => {
    const scheme = schemes[theme]
    if (!scheme) reporter.error('Unknown theme:', theme)
    return scheme
  }
}

describe('theme toggle resolution', () => {
  it('follows exactly one opposite transition', async () => {
    const { reporter } = createReporter()
    const result = await resolveThemeToggle(
      reporter,
      'catppuccin-frappe',
      createSchemeLoader(),
    )

    assert.equal(result.ok && result.theme, 'catppuccin-mocha')
  })

  it('uses the explicitly supplied theme as the transition source', async () => {
    const { reporter } = createReporter()
    const result = await resolveThemeToggle(
      reporter,
      'catppuccin-latte',
      createSchemeLoader(),
    )

    assert.equal(result.ok && result.theme, 'catppuccin-frappe')
  })

  it('keeps themes that do not declare an opposite', async () => {
    const { reporter } = createReporter()
    const result = await resolveThemeToggle(
      reporter,
      'standalone',
      createSchemeLoader(),
    )

    assert.equal(result.ok && result.theme, 'standalone')
  })

  it('returns an explicit failure when the source theme cannot be loaded', async () => {
    const { reporter, errors } = createReporter()
    const result = await resolveThemeToggle(
      reporter,
      'missing',
      createSchemeLoader(),
    )

    assert.equal(result.ok, false)
    assert.equal(errors.length, 1)
  })
})

describe('theme app application', () => {
  it('does not apply any app when preparation rejects', async () => {
    const { errors, reporter } = createReporter()
    const applied = []
    const configuredApps = [{ name: 'ok' }, { name: 'failed' }]
    const result = await applyThemeToApps(
      reporter,
      /** @type {never} */ ({}),
      /** @type {never} */ (configuredApps),
      async (_reporter, app) => {
        if (app.name === 'failed') throw new Error('apply failed')
        return async () => {
          applied.push(app.name)
        }
      },
    )

    assert.equal(result, false)
    assert.equal(errors.length, 1)
    assert.deepEqual(applied, [])
  })

  it('returns success when every configured app resolves', async () => {
    const { reporter } = createReporter()
    const result = await applyThemeToApps(
      reporter,
      /** @type {never} */ ({}),
      /** @type {never} */ ([{ name: 'ok' }]),
      async () => async () => {},
    )

    assert.equal(result, true)
  })

  it('returns failure when a prepared application rejects', async () => {
    const { errors, reporter } = createReporter()
    const result = await applyThemeToApps(
      reporter,
      /** @type {never} */ ({}),
      /** @type {never} */ ([{ name: 'failed' }]),
      async () => async () => {
        throw new Error('apply failed')
      },
    )

    assert.equal(result, false)
    assert.equal(errors.length, 1)
  })

  it('does not apply any app when Ghostty shader validation fails', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ghostty-theme-apply-'))
    const { reporter } = createReporter()
    const configuredAlacritty = apps.find(app => app.name === 'alacritty')
    const configuredGhostty = apps.find(app => app.name === 'ghostty')
    assert.ok(configuredAlacritty)
    assert.ok(configuredGhostty)
    const alacritty = {
      ...configuredAlacritty,
      home: path.join(root, 'alacritty'),
      active: () => true,
      render: async () => 'new alacritty theme\n',
      after_apply: undefined,
    }
    const ghostty = {
      ...configuredGhostty,
      home: path.join(root, 'ghostty'),
      active: () => true,
      render: async () => 'new ghostty theme\n',
      after_apply: undefined,
    }

    try {
      fs.mkdirSync(path.join(ghostty.home, 'local'), { recursive: true })
      fs.writeFileSync(path.join(ghostty.home, 'local/theme.conf'), 'old theme\n')
      fs.writeFileSync(
        path.join(ghostty.home, 'local/shader.conf'),
        'custom-shader = /tmp/custom.glsl\n',
      )

      const result = await applyThemeToApps(
        reporter,
        /** @type {never} */ ({ darken: false }),
        /** @type {never} */ ([alacritty, ghostty]),
      )

      assert.equal(result, false)
      assert.equal(
        fs.existsSync(path.join(alacritty.home, 'local/theme.toml')),
        false,
      )
      assert.equal(
        fs.readFileSync(path.join(ghostty.home, 'local/theme.conf'), 'utf8'),
        'old theme\n',
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })
})
