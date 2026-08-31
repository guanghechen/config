import fs from 'node:fs/promises'
import path from 'node:path'

import { render_template } from '#cli/theme/util'
import {
  F_WINDOWS_TERMINAL_SETTINGS,
  XDG_CONFIG_HOME,
} from '#env'

const settingsPath = F_WINDOWS_TERMINAL_SETTINGS
  ? path.resolve(F_WINDOWS_TERMINAL_SETTINGS)
  : null

export default {
  location: settingsPath ? path.dirname(settingsPath) : XDG_CONFIG_HOME,
  active: { file: '${local}' },
  themes: null,
  extname: '.json',
  local: settingsPath,
  on_render: async function (app, template, scheme) {
    if (!app.local) return ''
    const raw_content = await fs.readFile(app.local, 'utf8')
    const settings = JSON.parse(raw_content)

    const raw_color_scheme = await render_template(template, scheme)
    const color_scheme = JSON.parse(raw_color_scheme)
    if (Array.isArray(settings.schemes)) {
      if (
        settings.schemes.some((/** @type {{ name: string }} */ s) => s.name === color_scheme.name)
      ) {
        settings.schemes = settings.schemes.map((/** @type {{ name: string }} */ s) =>
          s.name === color_scheme.name ? color_scheme : s,
        )
      } else {
        settings.schemes.push(color_scheme)
      }
    } else {
      settings.schemes = [color_scheme]
    }

    settings.profiles = settings.profiles || {}
    settings.profiles.defaults = settings.profiles.defaults || {}
    settings.profiles.defaults.bellStyle = ['window']
    settings.profiles.defaults.colorScheme = color_scheme.name
    settings.profiles.defaults.cursorShape = 'bar'
    settings.profiles.defaults.opacity = 100
    settings.profiles.defaults.useAcrylic = true
    settings.profiles.defaults.font = settings.profiles.defaults.font || {}
    settings.profiles.defaults.font.face = 'Maple Mono NF CN'
    settings.profiles.defaults.font.weight = 'normal'
    settings.profiles.defaults.font.features = {
      cv61: 1,
      cv62: 1,
      cv98: 1,
      ss03: 1,
      ss07: 1,
      ss09: 1,
      ss10: 1,
      calt: 1,
    }

    if (scheme.darken) {
      settings.profiles.defaults.backgroundImage = null
      // "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Flowerlit-Prayers.jpg";
    } else {
      settings.profiles.defaults.backgroundImage = null
      // "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Barrett-Girl.jpg";
    }
    return JSON.stringify(settings, null, 2)
  },
}
