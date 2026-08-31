import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'fzf'),
  active: { directory: '.' },
  themes: null,
  extname: '.fzfrc',
  local: 'fzf.fzfrc',
}
