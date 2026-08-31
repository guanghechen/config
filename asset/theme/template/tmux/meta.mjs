import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { exec } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'tmux'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.tmux.conf',
  local: 'local/theme.tmux.conf',
  on_after_apply: async function (app, _scheme, reporter) {
    if (!process.env.TMUX) return

    const script_filepath = path.join(app.home, 'script/load-theme.sh')
    try {
      await exec({ reporter, cmd: '/bin/bash', args: [script_filepath], silent: true })
    } catch {
      reporter.error('Failed to load tmux theme.')
    }
  },
}
