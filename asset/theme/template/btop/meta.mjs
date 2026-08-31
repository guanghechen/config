import path from 'node:path'

import { PLATFORM, XDG_CONFIG_HOME } from '#env'
import { command_exists, signal_process } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'btop'),
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.theme',
  local: 'themes/local.theme',
  on_after_apply: async function (_app, _scheme, reporter) {
    if (PLATFORM === 'win') return
    if (!await command_exists(reporter, 'btop')) return
    try {
      await signal_process(reporter, 'SIGUSR2', 'btop')
    } catch {
      reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x btop')
    }
  },
}
