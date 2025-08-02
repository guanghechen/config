import fs from "node:fs/promises";
import path from "node:path";
import { XDG_CONFIG_HOME } from "../_shared/env.mjs";
import { is_directory, is_file, touch } from "../_shared/util.mjs";
import { render_template, safe_exec } from "./_util.mjs";

/** @type {import("./_env.mjs").IAppConfig[]} */
export const apps = [
  {
    name: "alacritty",
    kind: "terminal",
    themes: "theme/",
    extname: ".toml",
    local: "local/theme.toml",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app) => {
      const main_config_filepath = path.join(
        XDG_CONFIG_HOME,
        app.name,
        "alacritty.toml",
      );
      await touch(main_config_filepath);
    },
  },
  {
    name: "ghostty",
    kind: "terminal",
    themes: "theme/",
    extname: "",
    local: "local/theme",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_filepath = path.join(XDG_CONFIG_HOME, app.name, app.local);
      let content = await fs.readFile(theme_filepath, "utf8");

      // const backgroundImagePath =
      //   scheme.variant === "light"
      //     ? path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Barrett-Girl.jpg')
      //     : path.resolve(XDG_CONFIG_HOME, 'guanghechen/config/wallpaper/Flowerlit-Prayers.jpg')
      //
      // content += '\n\n' + `background_image = ${backgroundImagePath}\n`
      await fs.writeFile(theme_filepath, content, "utf8");
    },
  },
  {
    name: "kitty",
    kind: "terminal",
    themes: "theme/",
    extname: ".conf",
    local: "local/theme.conf",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_filepath = path.join(XDG_CONFIG_HOME, app.name, app.local);
      let content = await fs.readFile(theme_filepath, "utf8");

      const backgroundImagePath =
        scheme.variant === "light"
          ? path.resolve(
              XDG_CONFIG_HOME,
              "guanghechen/config/wallpaper/Barrett-Girl.jpg",
            )
          : path.resolve(
              XDG_CONFIG_HOME,
              "guanghechen/config/wallpaper/Flowerlit-Prayers.jpg",
            );

      if (scheme.theme === "gruvbox-dark" || scheme.theme === "gruvbox-light") {
        content += "\n\n" + `background_image ${backgroundImagePath}\n`;
      }
      await fs.writeFile(theme_filepath, content, "utf8");
    },
  },
  {
    name: "lazygit",
    kind: "other",
    themes: "theme/",
    extname: ".yml",
    local: "local/theme.yml",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: "nvim",
    kind: "neovim",
    themes: "lua/eve/constant/theme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(
        XDG_CONFIG_HOME,
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
    name: "nvim-nvchad",
    kind: "neovim",
    themes: "lua/eve/constant/theme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const theme_config_filepath = path.join(
        XDG_CONFIG_HOME,
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
    kind: "terminal",
    themes: "theme/",
    extname: ".tmux.conf",
    local: "local/theme.tmux.conf",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app) => {
      if (process.env.TMUX) {
        const script_filepath = path.join(
          XDG_CONFIG_HOME,
          app.name,
          "script/load-theme.sh",
        );
        await safe_exec("/bin/bash", [script_filepath]);
      }
    },
  },
  {
    name: "wezterm",
    kind: "terminal",
    themes: "theme/",
    extname: ".lua",
    local: "local/theme.lua",
    active: (app) => is_directory(path.join(XDG_CONFIG_HOME, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, scheme) => {
      const backgroundImagePath =
        scheme.variant === "light"
          ? path.resolve(
              XDG_CONFIG_HOME,
              "guanghechen/config/wallpaper/Barrett-Girl.jpg",
            )
          : path.resolve(
              XDG_CONFIG_HOME,
              "guanghechen/config/wallpaper/Flowerlit-Prayers.jpg",
            );

      const theme_filepath = path.join(XDG_CONFIG_HOME, app.name, app.local);
      let content = await fs.readFile(theme_filepath, "utf8");

      content = content.replace(
        "return config",
        `
config.background ={
{
source = { Color = "${scheme.palette.bg0}" },
height = "100%",
width = "100%",
},
{
source = { File = '${backgroundImagePath}' },
attachment = "Fixed",
height = "Contain",
width = "100%",
opacity = 0.9,
repeat_x = "Mirror",
repeat_y = "NoRepeat",
horizontal_align = "Right",
vertical_align = "Middle",
},
{
source = { Color = "${scheme.palette.bg0}" },
height = "100%",
width = "100%",
opacity = 0.9,
},
}

return config
`.trim(),
      );
      await fs.writeFile(theme_filepath, content, "utf8");
    },
  },
  {
    name: "windows_terminal",
    kind: "terminal",
    themes: null,
    extname: ".json",
    local: process.env.f_windows_terminal_settings,
    active: (app) => is_file(app.local),
    render: async (app, template, scheme) => {
      const raw_content = await fs.readFile(app.local, "utf8");
      const settings = JSON.parse(raw_content);

      const raw_color_scheme = await render_template(template, scheme);
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

      settings.profiles = settings.profiles || {};
      settings.profiles.defaults = settings.profiles.defaults || {};
      settings.profiles.defaults.colorScheme = color_scheme.name;
      settings.profiles.defaults.opacity = 100;
      settings.profiles.defaults.useAcrylic = true;

      switch (scheme.variant) {
        case "dark":
          settings.profiles.defaults.backgroundImage =
            "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Flowerlit-Prayers.jpg";
          break;
        case "light":
          settings.profiles.defaults.backgroundImage =
            "%XDG_CONFIG_HOME%\\guanghechen\\config\\wallpaper\\Barrett-Girl.jpg";
          break;
        case "neutral":
          break;
        default:
      }

      return JSON.stringify(settings, null, 2);
    },
  },
];
