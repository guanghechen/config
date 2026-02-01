import { existsSync, mkdirSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'

import {
  IS_NIX,
  IS_OSX,
  IS_WIN,
  IS_WSL,
  XDG_CONFIG_NODE_ASSET_THEME_APP_DIR,
  XDG_CONFIG_NODE_ASSET_THEME_SCHEME_DIR,
  XDG_CONFIG_NODE_ASSET_THEMES,
} from '#env'
import { Reporter } from '#stl/reporter'
import { hex2ansi256 } from '#util/color'

/** @typedef {import("./types.d.ts").IAppConfig} IAppConfig */
/** @typedef {import("./types.d.ts").IThemeScheme} IThemeScheme */

const reporter = new Reporter({ prefix: 'theme' })

/**
 * @param {string} theme
 * @param {string|undefined|null} variant
 * @return {string}
 */
export function gen_full_theme_name(theme, variant) {
  return variant ? `${theme}-${variant}` : theme
}

/**
 * @param {string} template
 * @param {IThemeScheme} scheme
 * @return {Promise<string>}
 */
export async function render_template(template, scheme) {
  const name = scheme.variant ? scheme.theme + '-' + scheme.variant : scheme.theme
  const uuid = scheme.uuid
  const theme = scheme.theme
  const variant = scheme.variant
  const opposite = scheme.opposite
  const darken = scheme.darken

  const catppuccin = scheme.palette.catppuccin
  const gruvbox = scheme.palette.gruvbox
  const nord = scheme.palette.nord
  const onehalf = scheme.palette.onehalf
  const rosepine = scheme.palette.rosepine
  const tokyonight = scheme.palette.tokyonight
  const vsc = scheme.palette.vsc
  const unified = scheme.palette.unified
  /** @type {Record<string, unknown>} */
  const palette = { catppuccin, gruvbox, nord, onehalf, rosepine, tokyonight, vsc, unified }
  const schemes = Object.keys(palette)

  const c256 = hex2ansi256

  const content = template
    .replace(/\\{3}\n[ \t ]*/g, '')
    .replace(/\{{2}([^\n]+?)\}{2}/g, (_, expression) => {
      const fn = new Function(
        'name',
        'IS_OSX',
        'IS_WIN',
        'IS_NIX',
        'IS_WSL',
        'uuid',
        'theme',
        'variant',
        'opposite',
        'darken',
        'palette',
        'c256',
        ...schemes,
        'expression',
        `try { return (${expression}) ?? expression; } catch (error) { console.log({ expression, error }); return \`{{\${expression}}}\`; }`,
      )
      const result = fn(
        name,
        IS_OSX,
        IS_WIN,
        IS_NIX,
        IS_WSL,
        uuid,
        theme,
        variant,
        opposite,
        darken,
        palette,
        c256,
        ...schemes.map(t => palette[t]),
        expression,
      )
      return result
    })
  return content
}

/**
 * @param {string} theme
 * @return {Promise<IThemeScheme|undefined>}
 */
export async function load_theme_scheme(theme) {
  const filepath = path.join(XDG_CONFIG_NODE_ASSET_THEME_SCHEME_DIR, `${theme}.json`)
  if (!existsSync(filepath)) {
    reporter.error('Unknown theme.', { theme })
    return
  }
  const content = await fs.readFile(filepath, 'utf8')
  try {
    const scheme = JSON.parse(content)

    /** @type {Record<string, string>} */
    let data = {}
    for (const key of Object.keys(scheme.palette)) {
      if (key !== 'unified') {
        data = { ...data, ...scheme.palette[key] }
      }
    }
    const resolvedContent = content.replaceAll(
      /\{{2}([\w]+)\}{2}/g,
      (_, key) => data[key] || `{{${key}}}`,
    )
    return JSON.parse(resolvedContent)
  } catch (error) {
    reporter.error('Bad scheme, not a valid json.', { theme, filepath, content })
    return
  }
}

/**
 * @param {IAppConfig} app
 * @param {IThemeScheme} scheme
 * @return {Promise<void>}
 */
export async function apply_theme_per_app(app, scheme) {
  if (!app.active(app)) return
  if (app.local) {
    const template_filepath = path.join(XDG_CONFIG_NODE_ASSET_THEME_APP_DIR, `${app.name}.hbs`)
    if (!existsSync(template_filepath)) {
      reporter.error('Cannot find the template.', { app: app.name })
      return
    }
    const template = await fs.readFile(template_filepath, 'utf8')
    const content = await app.render(app, template, scheme)

    const theme_filepath = path.resolve(app.home, app.local)
    mkdirSync(path.dirname(theme_filepath), { recursive: true })
    await fs.writeFile(theme_filepath, content, 'utf8')
  }

  await app.after_apply?.(app, scheme)
}

/**
 * @param {IAppConfig} app
 * @return {Promise<void>}
 */
export async function gen_themes_per_app(app) {
  if (!app.active(app)) return

  const template_filepath = path.join(XDG_CONFIG_NODE_ASSET_THEME_APP_DIR, `${app.name}.hbs`)
  if (!existsSync(template_filepath)) {
    reporter.error('Cannot find the template.', { app: app.name })
    return
  }
  const template = await fs.readFile(template_filepath, 'utf8')

  const tasks_gen_theme = XDG_CONFIG_NODE_ASSET_THEMES.map(theme => gen_theme(theme))
  await Promise.allSettled(tasks_gen_theme)
  await app.after_gen?.(app)

  /**
   * @param {string} theme
   * @return {Promise<void>}
   */
  async function gen_theme(theme) {
    /** @type {IThemeScheme|undefined} */
    const scheme = await load_theme_scheme(theme)
    if (!scheme) return

    const content = await app.render(app, template, scheme)

    if (app.themes) {
      const THEME_HOME = path.resolve(app.home, app.themes)
      const theme_filepath = path.resolve(THEME_HOME, `${theme}${app.extname}`)
      mkdirSync(path.dirname(theme_filepath), { recursive: true })
      await fs.writeFile(theme_filepath, content, 'utf8')
    }
  }
}
