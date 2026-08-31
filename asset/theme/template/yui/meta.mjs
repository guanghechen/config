import path from 'node:path'

import { PLATFORM, XDG_CONFIG_HOME } from '#env'
import { signal_process } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'yui'),
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.toml',
  local: 'themes/local.toml',
  on_after_apply: async function (_app, _scheme, reporter) {
    if (PLATFORM === 'win') return
    try {
      await signal_process(reporter, 'SIGUSR2', 'yui-tui')
    } catch {
      reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x yui-tui')
    }
  },
}
