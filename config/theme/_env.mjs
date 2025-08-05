import { readdirSync } from "node:fs";
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const cwd = __dirname;
export const HOME_THEME_SCHEME = path.join(__dirname, "scheme");
export const HOME_THEME_APP = path.join(__dirname, "app");
export const themes = readdirSync(HOME_THEME_SCHEME).map((p) =>
  p.replace(/\.json$/, ""),
);

/**
 * @typedef {Object} IThemeCatppuccinPalette
 * @property {string}                   base
 * @property {string}                   blue
 * @property {string}                   crust
 * @property {string}                   flamingo
 * @property {string}                   green
 * @property {string}                   lavender
 * @property {string}                   mantle
 * @property {string}                   maroon
 * @property {string}                   mauve
 * @property {string}                   overlay0
 * @property {string}                   overlay1
 * @property {string}                   overlay2
 * @property {string}                   peach
 * @property {string}                   pink
 * @property {string}                   red
 * @property {string}                   rosewater
 * @property {string}                   sapphire
 * @property {string}                   sky
 * @property {string}                   subtext0
 * @property {string}                   subtext1
 * @property {string}                   surface0
 * @property {string}                   surface1
 * @property {string}                   surface2
 * @property {string}                   teal
 * @property {string}                   text
 * @property {string}                   yellow
 */

/**
 * @typedef {Object} IThemeGruvboxPalette
 * @property {string}                   aqua
 * @property {string}                   bg
 * @property {string}                   bg0
 * @property {string}                   bg0_h
 * @property {string}                   bg0_s
 * @property {string}                   bg1
 * @property {string}                   bg2
 * @property {string}                   bg3
 * @property {string}                   bg4
 * @property {string}                   blue
 * @property {string}                   dark_aqua
 * @property {string}                   dark_blue
 * @property {string}                   dark_gray
 * @property {string}                   dark_green
 * @property {string}                   dark_orange
 * @property {string}                   dark_purple
 * @property {string}                   dark_red
 * @property {string}                   dark_yellow
 * @property {string}                   fg
 * @property {string}                   fg0
 * @property {string}                   fg1
 * @property {string}                   fg2
 * @property {string}                   fg3
 * @property {string}                   fg4
 * @property {string}                   gray
 * @property {string}                   green
 * @property {string}                   light_gray
 * @property {string}                   orange
 * @property {string}                   purple
 * @property {string}                   red
 * @property {string}                   yellow
 */

/**
 * @typedef {Object} IThemeNordPalette
 * @property {string}                   nord0
 * @property {string}                   nord1
 * @property {string}                   nord2
 * @property {string}                   nord3
 * @property {string}                   nord4
 * @property {string}                   nord5
 * @property {string}                   nord6
 * @property {string}                   nord7
 * @property {string}                   nord8
 * @property {string}                   nord9
 * @property {string}                   nord10
 * @property {string}                   nord11
 * @property {string}                   nord12
 * @property {string}                   nord13
 * @property {string}                   nord14
 * @property {string}                   nord15
 * @property {string}                   polarNight0
 * @property {string}                   polarNight1
 * @property {string}                   polarNight2
 * @property {string}                   polarNight3
 * @property {string}                   snowStorm0
 * @property {string}                   snowStorm1
 * @property {string}                   snowStorm2
 * @property {string}                   frost0
 * @property {string}                   frost1
 * @property {string}                   frost2
 * @property {string}                   frost3
 * @property {string}                   aurora0
 * @property {string}                   aurora1
 * @property {string}                   aurora2
 * @property {string}                   aurora3
 * @property {string}                   aurora4
 */

/**
 * @typedef {Object} IThemeOnehalfPalette
 * @property {string}                   background
 * @property {string}                   black
 * @property {string}                   blue
 * @property {string}                   comment
 * @property {string}                   cyan
 * @property {string}                   foreground
 * @property {string}                   green
 * @property {string}                   gutter
 * @property {string}                   guide
 * @property {string}                   orange
 * @property {string}                   purple
 * @property {string}                   red
 * @property {string}                   selection
 * @property {string}                   white
 * @property {string}                   yellow
 */

/**
 * @typedef {Object} IThemeRosepinePalette
 * @property {string}                   base
 * @property {string}                   foam
 * @property {string}                   gold
 * @property {string}                   highlightHigh
 * @property {string}                   highlightLow
 * @property {string}                   highlightMed
 * @property {string}                   iris
 * @property {string}                   love
 * @property {string}                   muted
 * @property {string}                   overlay
 * @property {string}                   pine
 * @property {string}                   rose
 * @property {string}                   subtle
 * @property {string}                   surface
 * @property {string}                   text
 */

/**
 * @typedef {Object} IThemeUnifiedPalette
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
 * @property {string}                   brightRed
 * @property {string}                   brightGreen
 * @property {string}                   brightYellow
 * @property {string}                   brightBlue
 * @property {string}                   brightPurple
 * @property {string}                   brightAqua
 * @property {string}                   brightOrange
 *
 * @property {string}                   grey
 * @property {string}                   pink
 *
 * @property {string}                   diffDel
 * @property {string}                   diffDelInline
 * @property {string}                   diffAdd
 * @property {string}                   diffAddInline
 */

/**
 * @typedef {Object} IThemePalette
 * @property {IThemeCatppuccinPalette|undefined}  catppuccin
 * @property {IThemeGruvboxPalette|undefined}     gruvbox
 * @property {IThemeNordPalette|undefined}        nord
 * @property {IThemeOnehalfPalette|undefined}     onehalf
 * @property {IThemeRosepinePalette|undefined}    rosepine
 * @property {IThemeUnifiedPalette}               unified
 */

/**
 * @typedef {Object} IThemeScheme
 * @property {string}                   theme
 * @property {string}                   variant
 * @property {string}                   opposite
 * @property {boolean}                  darken
 * @property {IThemePalette}            palette
 *
 * @typedef {Object} IAppConfig
 * @property {string}                   name
 * @property {"terminal"|"neovim"|"other"} kind
 * @property {string|null}              themes
 * @property {string}                   extname
 * @property {string|null}              local
 * @property {(app: IAppConfig) => boolean}  active
 * @property {(app: IAppConfig, template: string, scheme: IThemeScheme) => string}  render
 * @property {?((app: IAppConfig, scheme: IThemeScheme) => Promise<void>)} after_apply
 */
