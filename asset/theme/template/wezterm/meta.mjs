import fs from 'node:fs/promises'
import path from 'node:path'

import { XDG_CONFIG_HOME, XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR } from '#env'

export default {
  location: path.join(XDG_CONFIG_HOME, 'wezterm'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.lua',
  local: 'local/theme.lua',
  on_after_apply: async function (app, scheme) {
    if (!app.local) return
    const backgroundImagePath = scheme.darken
      ? path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.jpg')
      : path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Barrett-Girl.jpg')

    const theme_filepath = path.join(app.home, app.local)
    let content = await fs.readFile(theme_filepath, 'utf8')
    const backgroundConfig = `
        config.background = {
          {
            source = { Color = "${scheme.palette.unified.bg0}" },
            height = "100%",
            width = "100%",
          },
          -- {
          --   source = { File = '${backgroundImagePath}' },
          --   attachment = "Fixed",
          --   height = "Contain",
          --   width = "100%",
          --   opacity = 0.9,
          --   repeat_x = "Mirror",
          --   repeat_y = "NoRepeat",
          --   horizontal_align = "Right",
          --   vertical_align = "Middle",
          -- },
          {
            source = { Color = "${scheme.palette.unified.bg0}" },
            height = "100%",
            width = "100%",
            opacity = 0.9,
          },
        }
      end`
      .split(/\n/g)
      .map(line => line.replace(/^[ ]{6}/, ''))
      .join('\n')

    content = content
      .replace(/^end$/m, backgroundConfig)
      .replace('@class theme.vsc_dark_modern', '@class theme.local')
    await fs.writeFile(theme_filepath, content, 'utf8')
  },
}
