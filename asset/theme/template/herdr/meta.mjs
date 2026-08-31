import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { command_exists, exec } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'herdr'),
  active: {
    all: [
      { file: 'config.shared.toml' },
      { file: 'script/sync.mjs' },
    ],
  },
  themes: 'theme/',
  extname: '.json',
  local: 'theme/local.json',
  on_after_apply: async function (app, _scheme, reporter) {
    await exec({
      reporter,
      cmd: process.execPath,
      args: [path.join(app.home, 'script', 'sync.mjs')],
    })

    if (!await command_exists(reporter, 'herdr')) return
    const { stdout } = await exec({
      reporter,
      cmd: 'herdr',
      args: ['status', 'server', '--json'],
      silent: true,
    })
    if (!JSON.parse(stdout).running) return

    await exec({ reporter, cmd: 'herdr', args: ['server', 'reload-config'], silent: true })
  },
}
