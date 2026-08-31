import fs from 'node:fs/promises'
import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { exec } from '#util/command'

export default {
  location: path.join(XDG_CONFIG_HOME, 'bat'),
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.tmTheme',
  local: null,
  on_after_apply: async function (app, scheme) {
    const filepath = path.join(app.home, 'config')
    const theme = scheme.variant ? `${scheme.theme}-${scheme.variant}` : scheme.theme
    await fs.writeFile(filepath, `--theme=${theme}`, 'utf8')
  },
  on_after_gen: async function (_app, reporter) {
    try {
      await exec({ reporter, cmd: 'bat', args: ['cache', '--build'], silent: true })
    } catch {
      reporter.error('Failed to rebuild cache. cmd: bat cache --build')
    }
  },
}
