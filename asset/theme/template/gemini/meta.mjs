import path from 'node:path'

import { GEMINI_CONFIG_DIR } from '#env'
import { touch } from '#util/path'

export default {
  location: GEMINI_CONFIG_DIR,
  active: { directory: '.' },
  themes: 'themes/',
  extname: '.json',
  local: 'local/theme.json',
  on_after_apply: async function (app, _scheme, reporter) {
    await touch(path.join(app.home, 'settings.json'), reporter)
  },
}
