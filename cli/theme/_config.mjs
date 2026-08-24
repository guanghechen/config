import fs from 'node:fs/promises'
import path from 'node:path'

import {
  CODEX_CONFIG_DIR,
  GEMINI_CONFIG_DIR,
  PLATFORM,
  XDG_CONFIG_HOME,
  XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR,
} from '#env'
import { command_exists, exec } from '#util/command'
import { is_directory, is_file, touch } from '#util/path'

import {
  applyGhosttyThemeAppearance,
  validateGhosttyThemeAppearance,
} from '../ghostty-shader/_state.mjs'
import { gen_full_theme_name, render_template } from './_util.mjs'

/** @typedef {import("./types.d.ts").IAppConfig} IAppConfig */
/** @typedef {import("./types.d.ts").IReporter} IReporter */

/** @type {IAppConfig[]} */
export const apps = [
  {
    name: 'alacritty',
    home: path.join(XDG_CONFIG_HOME, 'alacritty'),
    themes: 'theme/',
    extname: '.toml',
    local: 'local/theme.toml',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, _scheme, reporter) => {
      const main_config_filepath = path.join(app.home, 'alacritty.toml')
      await touch(main_config_filepath, reporter)
    },
  },
  {
    name: 'bat',
    home: path.join(XDG_CONFIG_HOME, 'bat'),
    themes: 'themes/',
    extname: '.tmTheme',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const main_config_filepath = path.join(app.home, 'config')
      const content = [
        `--theme=${scheme.variant ? scheme.theme + '-' + scheme.variant : scheme.theme}`,
      ].join('\n')
      await fs.writeFile(main_config_filepath, content, 'utf8')
    },
    after_gen: async (_app, reporter) => {
      try {
        await exec({ reporter, cmd: 'bat', args: ['cache', '--build'], silent: true })
      } catch {
        reporter.error('Failed to rebuild cache. cmd: bat cache --build')
      }
    },
  },
  {
    name: 'codex',
    home: CODEX_CONFIG_DIR,
    themes: 'themes/',
    extname: '-ghc.tmTheme',
    local: 'themes/local.tmTheme',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'btop',
    home: path.join(XDG_CONFIG_HOME, 'btop'),
    themes: 'themes/',
    extname: '.theme',
    local: 'themes/local.theme',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (_app, _scheme, reporter) => {
      // Send SIGUSR2 to btop to trigger hot reload (Unix only, Windows doesn't support SIGUSR2)
      if (PLATFORM !== 'win') {
        const is_btop_exist = await command_exists(reporter, 'btop')
        if (is_btop_exist) {
          try {
            await exec({ reporter, cmd: 'pkill', args: ['-USR2', '-x', 'btop'], silent: true })
          } catch {
            reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x btop')
          }
        }
      }
    },
  },
  {
    name: 'fzf',
    home: path.join(XDG_CONFIG_HOME, 'fzf'),
    themes: null,
    extname: '.fzfrc',
    local: 'fzf.fzfrc',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'gemini',
    home: GEMINI_CONFIG_DIR,
    themes: 'themes/',
    extname: '.json',
    local: 'local/theme.json',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, _scheme, reporter) => {
      const main_config_filepath = path.join(app.home, 'settings.json')
      await touch(main_config_filepath, reporter)
    },
  },
  {
    name: 'ghostty',
    home: path.join(XDG_CONFIG_HOME, 'ghostty'),
    themes: 'theme/',
    extname: '',
    local: 'local/theme.conf',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    prepare: async (app, _content, scheme) => {
      await validateGhosttyThemeAppearance({
        home: app.home,
        appearance: scheme.darken ? 'dark' : 'light',
      })
    },
    apply: async (app, content, scheme) => {
      await applyGhosttyThemeAppearance({
        home: app.home,
        appearance: scheme.darken ? 'dark' : 'light',
        themeContent: content,
      })
    },
    after_apply: async (_app, _scheme, reporter) => {
      // Send SIGUSR2 to ghostty to trigger hot reload (Unix only, Windows doesn't support SIGUSR2)
      if (PLATFORM !== 'win') {
        const is_ghostty_exist = await command_exists(reporter, 'ghostty')
        if (is_ghostty_exist) {
          try {
            await exec({ reporter, cmd: 'pkill', args: ['-USR2', '-x', 'ghostty'], silent: true })
          } catch {
            reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x ghostty')
          }
        }
      }
    },
  },
  {
    name: 'herdr',
    home: path.join(XDG_CONFIG_HOME, 'herdr'),
    themes: 'theme/',
    extname: '.json',
    local: 'theme/local.json',
    active: app =>
      is_file(path.join(app.home, 'config.shared.toml')) &&
      is_file(path.join(app.home, 'script', 'sync.mjs')),
    render: async (_app, template, scheme) => render_template(template, scheme),
    after_apply: async (app, _scheme, reporter) => {
      await exec({
        reporter,
        cmd: process.execPath,
        args: [path.join(app.home, 'script', 'sync.mjs')],
      })

      const is_herdr_exist = await command_exists(reporter, 'herdr')
      if (!is_herdr_exist) return

      const { stdout } = await exec({
        reporter,
        cmd: 'herdr',
        args: ['status', 'server', '--json'],
        silent: true,
      })
      if (!JSON.parse(stdout).running) return

      await exec({ reporter, cmd: 'herdr', args: ['server', 'reload-config'], silent: true })
    },
  },
  {
    name: 'git-delta',
    home: path.join(XDG_CONFIG_HOME, 'git-delta'),
    themes: 'theme/',
    extname: '.conf',
    local: 'config.conf',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'kitty',
    home: path.join(XDG_CONFIG_HOME, 'kitty'),
    themes: 'theme/',
    extname: '.conf',
    local: 'local/theme.conf',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      if (!app.local) return
      const theme_filepath = path.join(app.home, app.local)
      let content = await fs.readFile(theme_filepath, 'utf8')

      const backgroundImagePath = scheme.darken
        ? path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.jpg')
        : path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Barrett-Girl.jpg')

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
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'newsboat',
    home: path.join(XDG_CONFIG_HOME, 'newsboat'),
    themes: 'theme/',
    extname: '',
    local: 'local/theme',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'nvim',
    home: path.join(XDG_CONFIG_HOME, 'nvim'),
    themes: 'lua/dot/theme/scheme/',
    extname: '.lua',
    local: null,
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme, reporter) => {
      const theme_config_filepath = path.join(app.home, 'init-theme.lua')
      try {
        await exec({
          reporter,
          cmd: 'nvim',
          args: ['--headless', '-u', theme_config_filepath, '+q'],
          env: {
            NVIM_APPNAME: app.name,
            GHC_THEME: gen_full_theme_name(scheme.theme, scheme.variant),
          },
          silent: true,
        })
      } catch {
        reporter.error('Failed to apply nvim theme.')
      }
    },
  },
  {
    name: 'nvim-nvchad',
    home: path.join(XDG_CONFIG_HOME, 'nvim-nvchad'),
    themes: 'lua/dot/theme/scheme/',
    extname: '.lua',
    local: null,
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme, reporter) => {
      const theme_config_filepath = path.join(app.home, 'init-theme.lua')
      try {
        await exec({
          reporter,
          cmd: 'nvim',
          args: ['--headless', '-u', theme_config_filepath, '+q'],
          env: {
            NVIM_APPNAME: app.name,
            GHC_THEME: gen_full_theme_name(scheme.theme, scheme.variant),
          },
          silent: true,
        })
      } catch {
        reporter.error('Failed to apply nvim-nvchad theme.')
      }
    },
  },
  {
    name: 'opencode',
    home: path.join(XDG_CONFIG_HOME, 'opencode'),
    themes: 'themes/',
    extname: '.json',
    local: 'themes/local.json',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'tmux',
    home: path.join(XDG_CONFIG_HOME, 'tmux'),
    themes: 'theme/',
    extname: '.tmux.conf',
    local: 'local/theme.tmux.conf',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, _scheme, reporter) => {
      if (process.env.TMUX) {
        const script_filepath = path.join(app.home, 'script/load-theme.sh')
        try {
          await exec({ reporter, cmd: '/bin/bash', args: [script_filepath], silent: true })
        } catch {
          reporter.error('Failed to load tmux theme.')
        }
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
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
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
  },
  {
    name: 'windows-terminal',
    home: process.env.f_windows_terminal_settings
      ? path.dirname(process.env.f_windows_terminal_settings)
      : XDG_CONFIG_HOME,
    themes: null,
    extname: '.json',
    local: process.env.f_windows_terminal_settings ?? null,
    active: app => is_file(app.local),
    render: async (app, template, scheme) => {
      if (!app.local) return ''
      const raw_content = await fs.readFile(app.local, 'utf8')
      const settings = JSON.parse(raw_content)

      const raw_color_scheme = await render_template(template, scheme)
      const color_scheme = JSON.parse(raw_color_scheme)
      if (Array.isArray(settings.schemes)) {
        if (
          settings.schemes.some((/** @type {{ name: string }} */ s) => s.name === color_scheme.name)
        ) {
          settings.schemes = settings.schemes.map((/** @type {{ name: string }} */ s) =>
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
    render: async (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: 'yui',
    home: path.join(XDG_CONFIG_HOME, 'yui'),
    themes: 'themes/',
    extname: '.toml',
    local: 'themes/local.toml',
    active: app => is_directory(app.home),
    render: async (_, template, scheme) => render_template(template, scheme),
    after_apply: async (_app, _scheme, reporter) => {
      // Send SIGUSR2 to yui-tui to trigger config reload (Unix only, Windows doesn't support SIGUSR2)
      if (PLATFORM !== 'win') {
        // NOTE: Do not gate by `command_exists('yui-tui')`.
        // yui-tui may be launched via cargo/target binary and not be discoverable in PATH.
        try {
          await exec({ reporter, cmd: 'pkill', args: ['-USR2', '-x', 'yui-tui'], silent: true })
        } catch {
          reporter.error('Failed to send reload signal. cmd: pkill -USR2 -x yui-tui')
        }
      }
    },
  },
]
