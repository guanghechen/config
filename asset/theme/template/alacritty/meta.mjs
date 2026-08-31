import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { touch } from '#util/path'

export default {
  location: path.join(XDG_CONFIG_HOME, 'alacritty'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.toml',
  local: 'local/theme.toml',
  on_after_apply: async function (app, _scheme, reporter) {
    await touch(path.join(app.home, 'alacritty.toml'), reporter)
  },
}
