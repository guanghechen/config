import path from 'node:path'

import { gen_full_theme_name } from '#cli/theme/util'
import { XDG_CONFIG_HOME } from '#env'
import { exec } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'nvim'),
  active: { directory: '.' },
  themes: 'lua/dot/theme/scheme/',
  extname: '.lua',
  local: null,
  on_after_apply: async function (app, scheme, reporter) {
    const theme_config_filepath = path.join(app.home, 'init-theme.lua')
    try {
      await exec({
        reporter,
        cmd: 'nvim',
        args: ['--headless', '-u', theme_config_filepath, '+q'],
        env: {
          NVIM_APPNAME: app.name,
          GHC_THEME: gen_full_theme_name(scheme.theme, scheme.variant),
        },
        silent: true,
      })
    } catch {
      reporter.error('Failed to apply nvim theme.')
    }
  },
}
