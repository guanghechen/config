import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'lazygit'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.yml',
  local: 'local/theme.yml',
}
