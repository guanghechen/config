import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'newsboat'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '',
  local: 'local/theme',
}
