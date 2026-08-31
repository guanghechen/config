import fs from 'node:fs/promises'
import path from 'node:path'

import { XDG_CONFIG_HOME, XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'kitty'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.conf',
  local: 'local/theme.conf',
  on_after_apply: async function (app, scheme) {
    if (!app.local) return
    const theme_filepath = path.join(app.home, app.local)
    let content = await fs.readFile(theme_filepath, 'utf8')

    const backgroundImagePath = scheme.darken
      ? path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.jpg')
      : path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Barrett-Girl.jpg')

    content += '\n\n' + `background_image ${backgroundImagePath}\n`
    await fs.writeFile(theme_filepath, content, 'utf8')
  },
}
