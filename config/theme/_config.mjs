import fs from 'node:fs/promises'
import path from "node:path";
import { HOME_CONFIG } from "./_env.mjs";
import {
  is_directory,
  is_file,
  render_template,
  touch,
  safe_exec,
} from "./_util.mjs";

/** @type {import("./_env.mjs").IAppConfig[]} */
export const apps = [
  {
    name: "alacritty",
    themes: "theme/",
    extname: ".toml",
    local: "local/theme.toml",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app) => {
      const main_config_filepath = path.join(
        HOME_CONFIG,
        app.name,
        "alacritty.toml",
      );
      await touch(main_config_filepath);
    },
  },
  {
    name: "kitty",
    themes: "theme/",
    extname: ".conf",
    local: "local/theme.conf",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const backgroundImagePath =
        scheme.variant === "light"
          ? path.resolve(HOME_CONFIG, 'guanghechen/config/wallpaper/Barrett-Girl.jpg')
          : path.resolve(HOME_CONFIG, 'guanghechen/config/wallpaper/Flowerlit-Prayers.jpg')

      const theme_filepath = path.join(HOME_CONFIG, app.name, app.local)
      let content = await fs.readFile(theme_filepath, 'utf8')
      content += '\n\n' + `background_image "${backgroundImagePath}"\n`
      await fs.writeFile(theme_filepath, content, 'utf8')
    },
  },
  {
    name: "lazygit",
    themes: "theme/",
    extname: ".yml",
    local: "local/theme.yml",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: "nvim",
    themes: "lua/eve/constant/theme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(
        HOME_CONFIG,
        app.name,
        "init-theme.lua",
      );
      await safe_exec(
        "nvim",
        ["--headless", "-u", theme_config_filepath, "+q"],
        {
          GHC_THEME: scheme.theme,
        }
      );
    },
  },
  {
    name: "nvim-nvchad",
    themes: "lua/eve/constant/theme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(
        HOME_CONFIG,
        app.name,
        "init-theme.lua",
      );
      await safe_exec(
        "nvim",
        ["--headless", "-u", theme_config_filepath, "+q"],
        {
          NVIM_APPNAME: app.name,
          GHC_THEME: scheme.theme,
        },
      );
    },
  },
  {
    name: "tmux",
    themes: "theme/",
    extname: ".tmux.conf",
    local: "local/theme.tmux.conf",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app) => {
      if (process.env.TMUX) {
        const script_filepath = path.join(
          HOME_CONFIG,
          app.name,
          "script/theme-reload.sh",
        );
        await safe_exec("/bin/bash", [script_filepath]);
      }
    },
  },
  {
    name: "wezterm",
    themes: "theme/",
    extname: ".lua",
    local: "local/theme.lua",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const backgroundImagePath =
        scheme.variant === "light"
          ? path.resolve(HOME_CONFIG, 'guanghechen/config/wallpaper/Barrett-Girl.jpg')
          : path.resolve(HOME_CONFIG, 'guanghechen/config/wallpaper/Flowerlit-Prayers.jpg')

      const theme_filepath = path.join(HOME_CONFIG, app.name, app.local)
      let content = await fs.readFile(theme_filepath, 'utf8')

      content = content.replace('return config', `
config.background ={
  {
    source = {
      File = '${backgroundImagePath}',
    },
    attachment = { Parallax = 0.1 },
    hsb = { brightness = 0.1 },
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
    size = "contain",
    position = "center",
  },
}

return config
`.trim())
      await fs.writeFile(theme_filepath, content, 'utf8')
    },
  },
  {
    name: "windows_terminal",
    themes: null,
    extname: ".json",
    local: process.env.f_windows_terminal_settings,
    active: (app) => is_file(app.local),
    render: async (app, template, scheme) => {
      const raw_content = await fs.readFile(app.local, "utf8");
      const settings = JSON.parse(raw_content);

      const raw_color_scheme = render_template(template, scheme);
      const color_scheme = JSON.parse(raw_color_scheme);
      if (Array.isArray(settings.schemes)) {
        if (settings.schemes.some((s) => s.name === color_scheme.name)) {
          settings.schemes = settings.schemes.map((s) =>
            s.name === color_scheme.name ? color_scheme : s,
          );
        } else {
          settings.schemes.push(color_scheme);
        }
      } else {
        settings.schemes = [color_scheme];
      }

      if (settings?.profiles?.defaults && typeof settings.profiles.defaults === 'object') {
        settings.profiles.defaults.colorScheme = color_scheme.name;
        switch (scheme.variant) {
          case 'dark':
            settings.profiles.defaults.backgroundImage = "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Flowerlit-Prayers.jpg";
            break
          case 'light':
            settings.profiles.defaults.backgroundImage = "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Barrett-Girl.jpg";
            break
          case 'neutral':
            break
          default:
        }
      }

      return JSON.stringify(settings, null, 2);
    },
  },
];
