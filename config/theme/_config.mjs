import fs from 'node:fs/promises'
import path from 'node:path'
import { GEMINI_CONFIG_DIR, XDG_CONFIG_HOME } from '../_shared/env.mjs'
import { is_directory, is_file, touch } from '../_shared/util.mjs'
import { command_exists, gen_full_theme_name, render_template, safe_exec } from './_util.mjs'

/** @typedef {import("./_types.mjs").IAppConfig} IAppConfig */

/** @type {IAppConfig[]} */
export const apps = [
  {
    name: 'alacritty',
    home: path.join(XDG_CONFIG_HOME, 'alacritty'),
    themes: 'theme/',
    extname: '.toml',
    local: 'local/theme.toml',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async app => {
      const main_config_filepath = path.join(app.home, 'alacritty.toml')
      await touch(main_config_filepath)
    },
  },
  {
    name: 'bat',
    home: path.join(XDG_CONFIG_HOME, 'bat'),
    themes: 'themes/',
    extname: '.tmTheme',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const main_config_filepath = path.join(app.home, 'config')
      const content = [
        `--theme=${scheme.variant ? scheme.theme + '-' + scheme.variant : scheme.theme}`,
      ].join('\n')
      await fs.writeFile(main_config_filepath, content, 'utf8')
    },
    after_gen: async () => {
      const result = await safe_exec('bat', ['cache', '--build'], { silent: true })
      if (!result) console.error('\x1b[31m[bat]\x1b[0m Failed to rebuild cache. cmd: \x1b[33mbat cache --build\x1b[0m')
    },
  },
  {
    name: 'btop',
    home: path.join(XDG_CONFIG_HOME, 'btop'),
    themes: 'themes/',
    extname: '.theme',
    local: null,
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const config_filepath = path.join(app.home, 'btop.conf')
      const theme_name = gen_full_theme_name(scheme.theme, scheme.variant)
      const content = await fs.readFile(config_filepath, 'utf8')
      const updated = content.replace(
        /^color_theme\s*=\s*".+?"$/m,
        `color_theme = "${theme_name}.theme"`,
      )
      await fs.writeFile(config_filepath, updated, 'utf8')

      // Send SIGUSR2 to btop to trigger hot reload
      const result = await safe_exec('pkill', ['-USR2', 'btop'], { silent: true })
      if (!result) console.error('\x1b[31m[btop]\x1b[0m Failed to send reload signal. cmd: \x1b[33mpkill -USR2 btop\x1b[0m')
    },
  },
  {
    name: 'fzf',
    home: path.join(XDG_CONFIG_HOME, 'fzf'),
    themes: 'themes/',
    extname: '.fzfrc',
    local: 'fzf.fzfrc',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'gemini',
    home: GEMINI_CONFIG_DIR,
    themes: 'themes/',
    extname: '.json',
    local: 'local/theme.json',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async app => {
      const main_config_filepath = path.join(app.home, 'settings.json')
      await touch(main_config_filepath)
    },
  },
  {
    name: 'ghostty',
    home: path.join(XDG_CONFIG_HOME, 'ghostty'),
    themes: 'theme/',
    extname: '',
    local: 'local/theme.conf',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async () => {
      const is_ghostty_exist = await command_exists('ghostty')
      if (is_ghostty_exist) {
        const result = await safe_exec('pkill', ['-USR2', 'ghostty'], { silent: true })
        if (!result) console.error('\x1b[31m[ghostty]\x1b[0m Failed to send reload signal. cmd: \x1b[33mpkill -USR2 ghostty\x1b[0m')
      }
    },
  },
  {
    name: 'git-delta',
    home: path.join(XDG_CONFIG_HOME, 'git-delta'),
    themes: 'theme/',
    extname: '.conf',
    local: 'config.conf',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'kitty',
    home: path.join(XDG_CONFIG_HOME, 'kitty'),
    themes: 'theme/',
    extname: '.conf',
    local: 'local/theme.conf',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_filepath = path.join(app.home, app.local)
      let content = await fs.readFile(theme_filepath, 'utf8')

      const backgroundImagePath = scheme.darken
        ? path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Flowerlit-Prayers.jpg')
        : path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Barrett-Girl.jpg')

      content += '\n\n' + `background_image ${backgroundImagePath}\n`
      await fs.writeFile(theme_filepath, content, 'utf8')
    },
  },
  {
    name: 'lazygit',
    home: path.join(XDG_CONFIG_HOME, 'lazygit'),
    themes: 'theme/',
    extname: '.yml',
    local: 'local/theme.yml',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'nvim',
    home: path.join(XDG_CONFIG_HOME, 'nvim'),
    themes: 'lua/ark/theme/scheme/',
    extname: '.lua',
    local: null,
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(app.home, 'init-theme.lua')
      await safe_exec('nvim', ['--headless', '-u', theme_config_filepath, '+q'], {
        env: {
          NVIM_APPNAME: app.name,
          GHC_THEME: gen_full_theme_name(scheme.theme, scheme.variant),
        },
      })
    },
  },
  {
    name: 'nvim-nvchad',
    home: path.join(XDG_CONFIG_HOME, 'nvim-nvchad'),
    themes: 'lua/ark/theme/scheme/',
    extname: '.lua',
    local: null,
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(app.home, 'init-theme.lua')
      await safe_exec('nvim', ['--headless', '-u', theme_config_filepath, '+q'], {
        env: {
          NVIM_APPNAME: app.name,
          GHC_THEME: gen_full_theme_name(scheme.theme, scheme.variant),
        },
      })
    },
  },
  {
    name: 'tmux',
    home: path.join(XDG_CONFIG_HOME, 'tmux'),
    themes: 'theme/',
    extname: '.tmux.conf',
    local: 'local/theme.tmux.conf',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async app => {
      if (process.env.TMUX) {
        const script_filepath = path.join(app.home, 'script/load-theme.sh')
        await safe_exec('/bin/bash', [script_filepath])
      }
    },
  },
  {
    name: 'wezterm',
    home: path.join(XDG_CONFIG_HOME, 'wezterm'),
    themes: 'theme/',
    extname: '.lua',
    local: 'local/theme.lua',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const backgroundImagePath = scheme.darken
        ? path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Flowerlit-Prayers.jpg')
        : path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Barrett-Girl.jpg')

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
  },
  {
    name: 'windows-terminal',
    home: process.env.f_windows_terminal_settings
      ? path.dirname(process.env.f_windows_terminal_settings)
      : XDG_CONFIG_HOME,
    themes: null,
    extname: '.json',
    local: process.env.f_windows_terminal_settings,
    active: app => is_file(app.local),
    render: async (app, template, scheme) => {
      const raw_content = await fs.readFile(app.local, 'utf8')
      const settings = JSON.parse(raw_content)

      const raw_color_scheme = await render_template(template, scheme)
      const color_scheme = JSON.parse(raw_color_scheme)
      if (Array.isArray(settings.schemes)) {
        if (settings.schemes.some(s => s.name === color_scheme.name)) {
          settings.schemes = settings.schemes.map(s =>
            s.name === color_scheme.name ? color_scheme : s,
          )
        } else {
          settings.schemes.push(color_scheme)
        }
      } else {
        settings.schemes = [color_scheme]
      }

      settings.profiles = settings.profiles || {}
      settings.profiles.defaults = settings.profiles.defaults || {}
      settings.profiles.defaults.bellStyle = ['window']
      settings.profiles.defaults.colorScheme = color_scheme.name
      settings.profiles.defaults.cursorShape = 'bar'
      settings.profiles.defaults.opacity = 100
      settings.profiles.defaults.useAcrylic = true
      settings.profiles.defaults.font = settings.profiles.defaults.font || {}
      settings.profiles.defaults.font.face = 'Maple Mono NF CN'
      settings.profiles.defaults.font.weight = 'normal'
      settings.profiles.defaults.font.features = {
        cv61: 1,
        cv62: 1,
        cv98: 1,
        ss03: 1,
        ss07: 1,
        ss09: 1,
        ss10: 1,
        calt: 1,
      }

      if (scheme.darken) {
        settings.profiles.defaults.backgroundImage = null
        // "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Flowerlit-Prayers.jpg";
      } else {
        settings.profiles.defaults.backgroundImage = null
        // "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Barrett-Girl.jpg";
      }
      return JSON.stringify(settings, null, 2)
    },
  },
  {
    name: 'yazi',
    home: path.join(XDG_CONFIG_HOME, 'yazi'),
    themes: 'theme/',
    extname: '.toml',
    local: 'theme.toml',
    active: app => is_directory(app.home),
    render: (_, template, scheme) => render_template(template, scheme),
  },
]
