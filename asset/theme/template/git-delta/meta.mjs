import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'git-delta'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.conf',
  local: 'config.conf',
}
