import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const HOME_THEME_SCHEME = path.join(__dirname, "scheme");
export const HOME_THEME_APP = path.join(__dirname, "app");
export const HOME_CONFIG =
  process.env.XDG_CONFIG_HOME ||
  (process.env.HOME ? path.join(process.env.HOME, ".config") : "");

export const themes = fs //
  .readdirSync(HOME_THEME_SCHEME)
  .map((p) => p.replace(/\.json$/, ""));

/**
 * @typedef {Object} IAppConfig
 * @property {string}                                                         name
 * @property {string|null}                                                    themes
 * @property {string}                                                         extname
 * @property {string|null}                                                    local
 * @property {(app: IAppConfig) => boolean}                                   active
 * @property {(app: IAppConfig, template: string, scheme: string) => string}  render
 * @property {?((app: IAppConfig, theme: string) => Promise<void>)}           after_apply
 */

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
    name: "lazygit",
    themes: "theme/",
    extname: ".yml",
    local: "local/theme.yml",
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
  },
  {
    name: "nvim",
    themes: "lua/fml/ux/theme/scheme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, theme) => {
      const theme_config_filepath = path.join(
        HOME_CONFIG,
        app.name,
        "theme.lua",
      );
      await safe_exec("nvim", [
        "--headless",
        "-c",
        `let g:ghc_theme='${theme}'`,
        "-c",
        `source ${theme_config_filepath}`,
        "+q",
      ]);
    },
  },
  {
    name: "nvim-nvchad",
    themes: "lua/fml/ux/theme/scheme/",
    extname: ".lua",
    local: null,
    active: (app) => is_directory(path.join(HOME_CONFIG, app.name)),
    render: (_, template, scheme) => render_template(template, scheme),
    after_apply: async (app, theme) => {
      const theme_config_filepath = path.join(
        HOME_CONFIG,
        app.name,
        "theme.lua",
      );
      await safe_exec(
        "nvim",
        [
          "--headless",
          "-c",
          `let g:ghc_theme='${theme}'`,
          "-c",
          `source ${theme_config_filepath}`,
          "+q",
        ],
        {
          NVIM_APPNAME: app.name,
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
    after_apply: async (app, theme) => {
      if (process.env.TMUX) {
        const main_config_filepath = path.join(
          HOME_CONFIG,
          app.name,
          "tmux.conf",
        );
        await safe_exec("tmux", [
          "set-environment",
          "-g",
          "@GHC_TMUX_THEME",
          theme,
        ]);
        await safe_exec("tmux", ["source-file", main_config_filepath]);
      }
    },
  },
  {
    name: "windows_terminal",
    themes: null,
    extname: ".json",
    local: process.env.f_windows_terminal_settings,
    active: (app) => is_file(app.local),
    render: (app, template, scheme) => {
      const raw_content = fs.readFileSync(app.local, "utf8");
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

      if (settings?.profiles?.defaults?.colorScheme) {
        settings.profiles.defaults.colorScheme = color_scheme.name;
      }

      return JSON.stringify(settings, null, 2);
    },
  },
];

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
function is_directory(filepath) {
  return (
    !!filepath && fs.existsSync(filepath) && fs.statSync(filepath).isDirectory()
  );
}

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
function is_file(filepath) {
  return (
    !!filepath && fs.existsSync(filepath) && fs.statSync(filepath).isFile()
  );
}

/**
 * @param {string}  template
 * @param {string}  raw_scheme
 * @return {string}
 */
function render_template(template, raw_scheme) {
  const scheme = JSON.parse(raw_scheme);
  const mode = scheme.mode;
  const c = scheme.palette;

  const data = {
    black: mode === "light" ? c.fg0 : c.bg0,
    white: mode === "light" ? c.bg4 : c.fg4,
    brightBlack: mode === "light" ? c.fg1 : c.bg1,
    brightWhite: mode === "light" ? c.bg1 : c.fg1,
    ...c,
    mode,
    theme: scheme.theme,
  };
  const content = template.replace(
    /\{{2}([\w]+)\}{2}/g,
    (_, key) => data[key] || `{{${key}}}`,
  );
  return content;
}

async function touch(filepath) {
  if (fs.existsSync(filepath)) {
    try {
      const now = new Date();
      fs.utimesSync(filepath, now, now);
    } catch (error) {
      console.error("[touch] Error touching file:", { filepath, error });
    }
  }
}

async function safe_exec(cmd, args, extendedEnv) {
  const encoding = "utf8";

  try {
    const stdout = await new Promise((resolve, reject) => {
      let stdoutData = "";
      let stderrData = "";
      let terminated = false;

      const onResolved = () => {
        if (!terminated) {
          terminated = true;
          resolve(stdoutData.trimEnd());
        }
      };

      const onRejected = (error) => {
        if (!terminated) {
          terminated = true;
          reject(error || new Error((stderrData || stdoutData).trimEnd()));
        }
      };

      try {
        const child = spawn(cmd, args, {
          cwd: __dirname,
          env: { ...process.env, ...extendedEnv },
          stdio: ["ignore", "pipe", "pipe"], // Suppress output
        });
        child.stdout?.on("data", (data) => {
          stdoutData += data.toString(encoding);
        });
        child.stderr?.on("data", (data) => {
          stderrData += data.toString(encoding);
        });
        child.on("close", (code) => {
          if (code === 0) onResolved();
          else onRejected();
        });
      } catch (error) {
        onRejected(error);
      }
    });

    return { stdout };
  } catch (error) {
    console.error(`['safe_exec'] Failed to run command.`, { cmd, args, error });
  }
}
