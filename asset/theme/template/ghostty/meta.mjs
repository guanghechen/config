import path from 'node:path'

import {
  applyGhosttyThemeAppearance,
  validateGhosttyThemeAppearance,
} from '#cli/theme/ghostty/state'
import { PLATFORM, XDG_CONFIG_HOME } from '#env'
import { command_exists, signal_process } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'ghostty'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '',
  local: 'local/theme.conf',
  on_prepare: async function (app, _content, scheme) {
    await validateGhosttyThemeAppearance({
      home: app.home,
      appearance: scheme.darken ? 'dark' : 'light',
    })
  },
  on_apply: async function (app, content, scheme) {
    await applyGhosttyThemeAppearance({
      home: app.home,
      appearance: scheme.darken ? 'dark' : 'light',
      themeContent: content,
    })
  },
  on_after_apply: async function (_app, _scheme, reporter) {
    if (PLATFORM === 'win') return
    if (!await command_exists(reporter, 'ghostty')) return
    try {
      await signal_process(reporter, 'SIGUSR2', 'ghostty')
    } catch {
      reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x ghostty')
    }
  },
}
