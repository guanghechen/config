import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

import { applyThemeToApps, resolveThemeToggle } from './theme.mjs'
import { apps } from './theme/config.mjs'
import {
  load_theme_scheme,
  render_template,
  resolve_app_template_filepath,
} from './theme/util.mjs'

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

describe('rosepine theme schemes', () => {
  const variants = [
    [
      'rosepine-main',
      '#21202E',
      ['#43293A', '#6D3A50', '#333C48', '#4D616C'],
    ],
    [
      'rosepine-moon',
      '#2A283E',
      ['#4B3148', '#73405B', '#3B4456', '#536777'],
    ],
    [
      'rosepine-dawn',
      '#F4EDE8',
      ['#ECD7D6', '#DEBABF', '#D9E1DD', '#B8CECE'],
    ],
  ]

  for (const [name, highlightLow, diff] of variants) {
    it(`follows the semantic role mapping for ${name}`, async () => {
      const { errors, reporter } = createReporter()
      const scheme = await load_theme_scheme(reporter, /** @type {string} */ (name))

      assert.equal(errors.length, 0)
      assert.ok(scheme)
      assert.ok(scheme.palette.rosepine)
      const { rosepine, unified } = scheme.palette
      assert.equal(rosepine.highlightLow, highlightLow)
      assert.deepEqual(
        [unified.bg0, unified.bg1, unified.bg2, unified.bg3, unified.bg4],
        [
          rosepine.base,
          rosepine.surface,
          rosepine.overlay,
          rosepine.highlightMed,
          rosepine.highlightHigh,
        ],
      )
      assert.deepEqual(
        [unified.fg0, unified.fg1, unified.fg2, unified.fg3, unified.fg4],
        [rosepine.text, rosepine.text, rosepine.subtle, rosepine.muted, rosepine.muted],
      )
      const accents = [
        rosepine.love,
        rosepine.pine,
        rosepine.gold,
        rosepine.foam,
        rosepine.iris,
        rosepine.rose,
        rosepine.rose,
      ]
      assert.deepEqual(
        [
          unified.red,
          unified.green,
          unified.yellow,
          unified.blue,
          unified.purple,
          unified.aqua,
          unified.orange,
        ],
        accents,
      )
      assert.deepEqual(
        [
          unified.brightRed,
          unified.brightGreen,
          unified.brightYellow,
          unified.brightBlue,
          unified.brightPurple,
          unified.brightAqua,
          unified.brightOrange,
        ],
        accents,
      )
      assert.deepEqual(
        [unified.black, unified.white, unified.grey, unified.pink],
        [rosepine.overlay, rosepine.text, rosepine.muted, rosepine.love],
      )
      assert.equal(unified.tokenComment, rosepine.subtle)
      assert.deepEqual(
        [unified.diffDel, unified.diffDelInline, unified.diffAdd, unified.diffAddInline],
        diff,
      )
    })
  }
})

describe('vsc theme schemes', () => {
  const variants = [
    [
      'vsc-dark-modern',
      '#264F78',
      ['#AEAFAD', '#E3E4E229', '#9CCC2C33', '#FF000033'],
      [
        '#000000', '#CD3131', '#0DBC79', '#DCDCAA',
        '#2472C8', '#BC3FBC', '#11A8CD', '#E5E5E5',
        '#666666', '#F14C4C', '#23D18B', '#F5F543',
        '#3B8EEA', '#D670D6', '#29B8DB', '#E5E5E5',
      ],
    ],
    [
      'vsc-light-modern',
      '#ADD6FF',
      ['#000000', '#33333333', '#9CCC2C40', '#FF000033'],
      [
        '#000000', '#CD3131', '#107C10', '#795E26',
        '#0451A5', '#BC05BC', '#0598BC', '#555555',
        '#666666', '#CD3131', '#14CE14', '#B5BA00',
        '#0451A5', '#BC05BC', '#0598BC', '#A5A5A5',
      ],
    ],
  ]

  for (const [name, selection, editor, ansi] of variants) {
    it(`follows the upstream editor and terminal roles for ${name}`, async () => {
      const { errors, reporter } = createReporter()
      const scheme = await load_theme_scheme(reporter, /** @type {string} */ (name))

      assert.equal(errors.length, 0)
      assert.ok(scheme)
      const { unified, vsc } = scheme.palette
      assert.equal(vsc.editor_selectionBackground, selection)
      assert.deepEqual(
        [
          vsc.editorCursor_foreground,
          vsc.editorWhitespace_foreground,
          vsc.diffEditor_insertedTextBackground,
          vsc.diffEditor_removedTextBackground,
        ],
        editor,
      )
      assert.deepEqual(
        [unified.diffDel, unified.diffDelInline, unified.diffAdd, unified.diffAddInline],
        [vsc.diffDel, vsc.diffDelInline, vsc.diffAdd, vsc.diffAddInline],
      )
      assert.deepEqual(
        [
          vsc.terminal_ansiBlack,
          vsc.terminal_ansiRed,
          vsc.terminal_ansiGreen,
          vsc.terminal_ansiYellow,
          vsc.terminal_ansiBlue,
          vsc.terminal_ansiMagenta,
          vsc.terminal_ansiCyan,
          vsc.terminal_ansiWhite,
          vsc.terminal_ansiBrightBlack,
          vsc.terminal_ansiBrightRed,
          vsc.terminal_ansiBrightGreen,
          vsc.terminal_ansiBrightYellow,
          vsc.terminal_ansiBrightBlue,
          vsc.terminal_ansiBrightMagenta,
          vsc.terminal_ansiBrightCyan,
          vsc.terminal_ansiBrightWhite,
        ],
        ansi,
      )
    })
  }
})

describe('kanagawa theme schemes', () => {
  const variants = [
    ['kanagawa-wave', true, 'lotus', '#1F1F28'],
    ['kanagawa-dragon', true, '', '#181616'],
    ['kanagawa-lotus', false, 'wave', '#F2ECBC'],
  ]

  for (const [name, darken, opposite, background] of variants) {
    it(`loads and renders ${name}`, async () => {
      const { errors, reporter } = createReporter()
      const scheme = await load_theme_scheme(reporter, /** @type {string} */ (name))

      assert.equal(errors.length, 0)
      assert.ok(scheme)
      assert.equal(scheme.theme, 'kanagawa')
      assert.equal(scheme.darken, darken)
      assert.equal(scheme.opposite, opposite)
      assert.equal(
        await render_template('{{kanagawa.crystalBlue}} {{unified.bg0}}', scheme),
        `#7E9CD8 ${background}`,
      )
    })
  }

  it('toggles wave to lotus through the real scheme files', async () => {
    const { errors, reporter } = createReporter()
    const result = await resolveThemeToggle(reporter, 'kanagawa-wave')

    assert.equal(errors.length, 0)
    assert.equal(result.ok && result.theme, 'kanagawa-lotus')
  })
})

describe('theme app template resolution', () => {
  it('prefers an exact theme-family template', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-template-'))
    const appDir = path.join(root, 'tmux')

    try {
      fs.mkdirSync(appDir, { recursive: true })
      fs.writeFileSync(path.join(appDir, 'default.hbs'), 'default\n')
      fs.writeFileSync(path.join(appDir, 'kanagawa.hbs'), 'kanagawa\n')

      assert.equal(
        resolve_app_template_filepath(
          /** @type {never} */ ({ name: 'tmux' }),
          /** @type {never} */ ({ theme: 'kanagawa' }),
          root,
        ),
        path.join(appDir, 'kanagawa.hbs'),
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('falls back to the app default template', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-template-'))
    const appDir = path.join(root, 'tmux')

    try {
      fs.mkdirSync(appDir, { recursive: true })
      fs.writeFileSync(path.join(appDir, 'default.hbs'), 'default\n')

      assert.equal(
        resolve_app_template_filepath(
          /** @type {never} */ ({ name: 'tmux' }),
          /** @type {never} */ ({ theme: 'kanagawa' }),
          root,
        ),
        path.join(appDir, 'default.hbs'),
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('reports missing templates with both attempted paths', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'theme-template-'))

    try {
      assert.throws(
        () => resolve_app_template_filepath(
          /** @type {never} */ ({ name: 'tmux' }),
          /** @type {never} */ ({ theme: 'kanagawa' }),
          root,
        ),
        error => {
          assert.match(error.message, /tmux/)
          assert.match(error.message, /kanagawa\.hbs/)
          assert.match(error.message, /default\.hbs/)
          return true
        },
      )
    } finally {
      fs.rmSync(root, { recursive: true, force: true })
    }
  })

  it('rejects unsafe app and family path segments', () => {
    assert.throws(
      () => resolve_app_template_filepath(
        /** @type {never} */ ({ name: '../tmux' }),
        /** @type {never} */ ({ theme: 'kanagawa' }),
      ),
      /Invalid app template path segment/,
    )
    assert.throws(
      () => resolve_app_template_filepath(
        /** @type {never} */ ({ name: 'tmux' }),
        /** @type {never} */ ({ theme: '../kanagawa' }),
      ),
      /Invalid theme family template path segment/,
    )
  })

  it('provides a default template for every configured app', () => {
    for (const app of apps) {
      assert.equal(
        resolve_app_template_filepath(
          app,
          /** @type {never} */ ({ theme: 'missing-family' }),
        ),
        path.resolve('asset/theme/template', app.name, 'default.hbs'),
      )
    }
  })

  it('provides resolved VSC templates for every non-Neovim app', async () => {
    const { errors, reporter } = createReporter()
    const schemes = await Promise.all([
      load_theme_scheme(reporter, 'vsc-dark-modern'),
      load_theme_scheme(reporter, 'vsc-light-modern'),
    ])
    assert.equal(errors.length, 0)

    for (const app of apps.filter(app => !['nvim', 'nvim-nvchad'].includes(app.name))) {
      const templatePath = resolve_app_template_filepath(
        app,
        /** @type {never} */ ({ theme: 'vsc' }),
      )
      assert.equal(
        templatePath,
        path.resolve('asset/theme/template', app.name, 'vsc.hbs'),
      )

      const template = fs.readFileSync(templatePath, 'utf8')
      for (const scheme of schemes) {
        assert.ok(scheme)
        const content = await render_template(template, scheme)
        assert.doesNotMatch(content, /\{\{[^\n]+\}\}/, `${app.name}/${scheme.variant}`)
      }
    }
  })

  it('keeps the Codex VSC theme equal to Bat plus explicit Codex extensions', () => {
    const templateRoot = path.resolve('asset/theme/template')
    const bat = fs.readFileSync(path.join(templateRoot, 'bat/vsc.hbs'), 'utf8')
    const codex = fs.readFileSync(path.join(templateRoot, 'codex/vsc.hbs'), 'utf8')
    const extensionPattern =
      /      <!-- BEGIN Codex extensions:[\s\S]*?      <!-- END Codex extensions\. -->\n/
    const extension = codex.match(extensionPattern)?.[0]

    assert.ok(extension)
    assert.match(extension, /markup\.inserted, markup\.inserted\.diff, diff\.inserted/)
    assert.match(extension, /markup\.deleted, markup\.deleted\.diff, diff\.deleted/)
    assert.match(extension, /entity\.name\.section/)
    assert.equal(codex.replace(extensionPattern, ''), bat)
  })

  it('composites Codex VSC diff backgrounds for its RGB-only renderer', async () => {
    const template = fs.readFileSync(
      path.resolve('asset/theme/template/codex/vsc.hbs'),
      'utf8',
    )
    const cases = [
      ['vsc-dark-modern', '#384222', '#4C1919'],
      ['vsc-light-modern', '#E6F2CA', '#FFCCCC'],
    ]

    for (const [name, inserted, deleted] of cases) {
      const { errors, reporter } = createReporter()
      const scheme = await load_theme_scheme(reporter, name)
      assert.equal(errors.length, 0)
      assert.ok(scheme)

      const content = await render_template(template, scheme)
      const extension = content.match(
        /      <!-- BEGIN Codex extensions:[\s\S]*?      <!-- END Codex extensions\. -->\n/,
      )?.[0]
      assert.ok(extension)
      assert.match(extension, new RegExp(`<string>${inserted}</string>`))
      assert.match(extension, new RegExp(`<string>${deleted}</string>`))
    }
  })

  it('owns VSC colors per app while preserving default output', async () => {
    const templateRoot = path.resolve('asset/theme/template')
    const { errors, reporter } = createReporter()
    const schemes = await Promise.all([
      load_theme_scheme(reporter, 'vsc-dark-modern'),
      load_theme_scheme(reporter, 'vsc-light-modern'),
    ])

    for (const app of apps.filter(app => !['nvim', 'nvim-nvchad'].includes(app.name))) {
      const defaultTemplate = fs.readFileSync(
        path.join(templateRoot, app.name, 'default.hbs'),
        'utf8',
      )
      const vscTemplate = fs.readFileSync(
        path.join(templateRoot, app.name, 'vsc.hbs'),
        'utf8',
      )
      assert.doesNotMatch(
        vscTemplate,
        /\b(?:unified|catppuccin|gruvbox|kanagawa|rosepine|tokyonight)\??\./,
        app.name,
      )

      if (['bat', 'codex'].includes(app.name)) {
        assert.notEqual(vscTemplate, defaultTemplate, app.name)
      } else {
        for (const scheme of schemes) {
          assert.ok(scheme)
          assert.equal(
            await render_template(vscTemplate, scheme),
            await render_template(defaultTemplate, scheme),
            `${app.name}/${scheme.variant}`,
          )
        }
      }
    }
    assert.equal(errors.length, 0)
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
