import { readdirSync } from "node:fs";
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const cwd = __dirname;
export const HOME_THEME_SCHEME = path.join(__dirname, "scheme");
export const HOME_THEME_APP = path.join(__dirname, "app");
export const HOME_CONFIG =
  process.env.XDG_CONFIG_HOME ||
  (process.env.HOME ? path.join(process.env.HOME, ".config") : "");
export const themes = readdirSync(HOME_THEME_SCHEME).map((p) =>
  p.replace(/\.json$/, ""),
);

/**
 * @typedef {Object} ITehemePalette
 * @property {string}                   bg0
 * @property {string}                   bg1
 * @property {string}                   bg2
 * @property {string}                   bg3
 * @property {string}                   bg4
 *
 * @property {string}                   fg0
 * @property {string}                   fg1
 * @property {string}                   fg2
 * @property {string}                   fg3
 * @property {string}                   fg4
 *
 * @property {string}                   red
 * @property {string}                   green
 * @property {string}                   yellow
 * @property {string}                   blue
 * @property {string}                   purple
 * @property {string}                   aqua
 * @property {string}                   orange
 *
 * @property {string}                   neutral_red
 * @property {string}                   neutral_green
 * @property {string}                   neutral_yellow
 * @property {string}                   neutral_blue
 * @property {string}                   neutral_purple
 * @property {string}                   neutral_aqua
 * @property {string}                   neutral_orange
 *
 * @property {string}                   grey
 * @property {string}                   pink
 *
 * @property {string}                   diff_del
 * @property {string}                   diff_del_inline
 * @property {string}                   diff_add
 * @property {string}                   diff_add_inline
 *
 * @typedef {Object} IThemeScheme
 * @property {string}                   theme
 * @property {'variant'|'dark'|'neutral'} variant
 * @property {string}                   opposite
 * @property {ITehemePalette}           palette
 *
 * @typedef {Object} IAppConfig
 * @property {string}                   name
 * @property {string|null}              themes
 * @property {string}                   extname
 * @property {string|null}              local
 * @property {(app: IAppConfig) => boolean}  active
 * @property {(app: IAppConfig, template: string, scheme: IThemeScheme) => string}  render
 * @property {?((app: IAppConfig, scheme: IThemeScheme) => Promise<void>)} after_apply
 */
