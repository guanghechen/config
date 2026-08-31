import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'opencode'),
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.json',
  local: 'themes/local.json',
}
