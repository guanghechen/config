import fs from 'node:fs/promises'
import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { load_theme_scheme, render_template } from '#cli/theme/util'

const variants = {
  catppuccin: { light: 'latte', dark: 'mocha' },
  gruvbox: { light: 'light', dark: 'dark' },
  kanagawa: { light: 'lotus', dark: 'wave' },
  rosepine: { light: 'dawn', dark: 'main' },
  tokyonight: { light: 'day', dark: 'night' },
  vsc: { light: 'light-modern', dark: 'dark-modern' },
}

export default {
  location: path.join(XDG_CONFIG_HOME, 'kit'),
  active: { directory: '.' },
  themes: '.theme/',
  extname: '.json',
  local: '.theme/local.json',
  on_render: async function (_app, template, scheme) {
    const pair = variants[scheme.theme]
    if (!pair) throw new Error(`No Kit theme pair for family: ${scheme.theme}`)
    const oppositeMode = scheme.darken ? 'light' : 'dark'
    const counterpart = await load_theme_scheme({
      error(message) { throw new Error(message) },
    }, `${scheme.theme}-${pair[oppositeMode]}`)
    if (!counterpart || counterpart.darken === scheme.darken) {
      throw new Error(`Invalid Kit theme pair for family: ${scheme.theme}`)
    }
    const palettes = {}
    for (const value of [scheme, counterpart]) {
      const rendered = await render_template(template, value)
      if (rendered.includes('{{')) throw new Error('Unresolved expression in Kit theme')
      const palette = JSON.parse(rendered)
      const keys = ['background', 'foreground', 'muted', 'accent', 'recording', 'error', 'border']
      if (Object.keys(palette).length !== keys.length ||
        keys.some(key => typeof palette[key] !== 'string' || !/^#[\da-f]{6}$/i.test(palette[key]))) {
        throw new Error('Kit theme colors must be #RRGGBB')
      }
      palettes[value.darken ? 'dark' : 'light'] = palette
    }
    return JSON.stringify({ version: 1, light: palettes.light, dark: palettes.dark }, null, 2) + '\n'
  },
  on_apply: async function (app, content) {
    const directory = path.join(app.home, app.themes)
    await fs.mkdir(directory, { recursive: true })
    const temporary = await fs.mkdtemp(path.join(directory, '.kit-theme-'))
    try {
      const staged = path.join(temporary, 'theme.json')
      await fs.writeFile(staged, content, { mode: 0o644 })
      await fs.rename(staged, path.join(app.home, app.local))
    } finally {
      await fs.rm(temporary, { recursive: true, force: true })
    }
  },
}
