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
import { hex2ansi256 } from '#util/color'

/** @typedef {import("./types.d.ts").IAppConfig} IAppConfig */
/** @typedef {import("./types.d.ts").IReporter} IReporter */
/** @typedef {import("./types.d.ts").IThemeScheme} IThemeScheme */

/**
 * @param {string} theme
 * @param {string|undefined|null} variant
 * @return {string}
 */
export function gen_full_theme_name(theme, variant) {
  return variant ? `${theme}-${variant}` : theme
}

const templateSegmentPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/**
 * Resolve an app template by theme family, falling back to the app default.
 * @param {Pick<IAppConfig, 'name'>} app
 * @param {Pick<IThemeScheme, 'theme'>} scheme
 * @param {string} [templateRoot]
 * @return {string}
 */
export function resolve_app_template_filepath(
  app,
  scheme,
  templateRoot = XDG_CONFIG_NODE_ASSET_THEME_APP_DIR,
) {
  for (const [kind, segment] of [['app', app.name], ['theme family', scheme.theme]]) {
    if (!templateSegmentPattern.test(segment)) {
      throw new Error(`Invalid ${kind} template path segment: ${segment}`)
    }
  }

  const templateDir = path.join(templateRoot, app.name)
  const candidates = [
    path.join(templateDir, `${scheme.theme}.hbs`),
    path.join(templateDir, 'default.hbs'),
  ]
  const filepath = candidates.find(candidate => existsSync(candidate))
  if (filepath) return filepath

  throw new Error(
    `Cannot find the template for app "${app.name}" and theme family "${scheme.theme}". ` +
    `Tried: ${candidates.join(', ')}`,
  )
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
  const kanagawa = scheme.palette.kanagawa
  const rosepine = scheme.palette.rosepine
  const tokyonight = scheme.palette.tokyonight
  const vsc = scheme.palette.vsc
  const unified = scheme.palette.unified
  /** @type {Record<string, unknown>} */
  const palette = { catppuccin, gruvbox, kanagawa, rosepine, tokyonight, vsc, unified }
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
 * @param {IReporter} reporter
 * @param {string} theme
 * @return {Promise<IThemeScheme|undefined>}
 */
export async function load_theme_scheme(reporter, theme) {
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
 * @param {IReporter} reporter
 * @param {IAppConfig} app
 * @param {IThemeScheme} scheme
 * @return {Promise<() => Promise<void>>}
 */
export async function prepare_theme_per_app(reporter, app, scheme) {
  if (!app.active(app)) return async () => {}

  let content
  if (app.local) {
    const template_filepath = resolve_app_template_filepath(app, scheme)
    const template = await fs.readFile(template_filepath, 'utf8')
    content = await app.render(app, template, scheme)
    await app.prepare?.(app, content, scheme, reporter)
  }

  return async () => {
    if (app.local && content !== undefined) {
      if (app.apply) {
        await app.apply(app, content, scheme, reporter)
      } else {
        const theme_filepath = path.resolve(app.home, app.local)
        mkdirSync(path.dirname(theme_filepath), { recursive: true })
        await fs.writeFile(theme_filepath, content, 'utf8')
      }
    }

    await app.after_apply?.(app, scheme, reporter)
  }
}

/**
 * @param {IReporter} reporter
 * @param {IAppConfig} app
 * @param {IThemeScheme} scheme
 * @return {Promise<void>}
 */
export async function apply_theme_per_app(reporter, app, scheme) {
  const apply = await prepare_theme_per_app(reporter, app, scheme)
  await apply()
}

/**
 * @param {IReporter} reporter
 * @param {IAppConfig} app
 * @return {Promise<void>}
 */
export async function gen_themes_per_app(reporter, app) {
  if (!app.active(app)) return

  const tasks_gen_theme = XDG_CONFIG_NODE_ASSET_THEMES.map(theme => gen_theme(theme))
  const results = await Promise.allSettled(tasks_gen_theme)
  const errors = results
    .filter(result => result.status === 'rejected')
    .map(result => result.reason)
  if (errors.length > 0) {
    throw new AggregateError(errors, `Failed to generate themes for app: ${app.name}`)
  }
  await app.after_gen?.(app, reporter)

  /**
   * @param {string} theme
   * @return {Promise<void>}
   */
  async function gen_theme(theme) {
    /** @type {IThemeScheme|undefined} */
    const scheme = await load_theme_scheme(reporter, theme)
    if (!scheme) return

    const template_filepath = resolve_app_template_filepath(app, scheme)
    const template = await fs.readFile(template_filepath, 'utf8')
    const content = await app.render(app, template, scheme)

    if (app.themes) {
      const THEME_HOME = path.resolve(app.home, app.themes)
      const theme_filepath = path.resolve(THEME_HOME, `${theme}${app.extname}`)
      mkdirSync(path.dirname(theme_filepath), { recursive: true })
      await fs.writeFile(theme_filepath, content, 'utf8')
    }
  }
}
