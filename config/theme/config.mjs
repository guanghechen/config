import fs from "node:fs";
import path from "node:path";
import url from "node:url";

export const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const HOME_THEME_SCHEME = path.join(__dirname, "scheme");
export const HOME_THEME_APP = path.join(__dirname, "app");
export const HOME_CONFIG =
  process.env.XDG_CONFIG_HOME ||
  (process.env.HOME ? path.join(process.env.HOME, ".config") : "");

export const themes = fs //
  .readdirSync(HOME_THEME_SCHEME)
  .map((p) => p.replace(/\.json$/, ""));

export const apps = {
  alacritty: {
    main: "alacritty.toml",
    extname: ".toml",
  },
  fish: {
    main: "config.fish",
    extname: ".fish",
  },
  lazygit: {
    main: "config.yml",
    extname: ".yml",
  },
  nvim: {
    main: "init.lua",
    scheme_home: "lua/ghc/ux/theme/scheme",
    extname: ".lua",
  },
  ["nvim-nvchad"]: {
    main: "init.lua",
    scheme_home: "lua/ghc/ux/theme/scheme",
    template: "nvim",
    extname: ".lua",
  },
  tmux: {
    main: "tmux.conf",
    extname: ".tmux.conf",
  },
  windows_terminal: {
    main: process.env.f_windows_terminal_settings,
    extname: ".json",
  },
};
