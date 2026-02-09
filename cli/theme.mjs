#!/usr/bin/env node

/**
 * Theme management CLI with subcommands: apply, gen, toggle.
 */

import { XDG_CONFIG_NODE_ASSET_THEMES, XDG_CONFIG_NODE_SETTING } from '#env'
import { Setting } from '#setting'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

import { apps } from './theme/_config.mjs'
import { apply_theme_per_app, gen_themes_per_app, load_theme_scheme } from './theme/_util.mjs'

/** @typedef {import("./theme/types.d.ts").IThemeScheme} IThemeScheme */

const reporter = new Reporter({ prefix: 'theme' })
const setting = new Setting({ filepath: XDG_CONFIG_NODE_SETTING, reporter })

// ============================================================
// Handlers
// ============================================================

/**
 * Apply a theme to all configured applications.
 * @param {string} [theme] - Theme name to apply
 * @return {Promise<void>}
 */
async function handleThemeApply(theme) {
  const data = await setting.load()
  theme = theme?.toLowerCase() || data.theme
  reporter.info('Applying theme:', theme)

  if (!XDG_CONFIG_NODE_ASSET_THEMES.includes(theme)) {
    reporter.error('Cannot find the given theme:', theme)
    return
  }

  /** @type {IThemeScheme|undefined} */
  const scheme = await load_theme_scheme(theme)
  if (!scheme) return

  const tasks = apps.map(app => apply_theme_per_app(app, scheme))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(/** @type {(r: PromiseSettledResult<unknown>) => r is PromiseRejectedResult} */ (result => result.status === 'rejected'))
      .map(result => result.reason),
  )

  if (errors.length > 0) {
    reporter.error('Errors encountered:', errors)
  } else {
    data.theme = theme
    await setting.save(data)
    reporter.info('Theme applied successfully')
  }
}

/**
 * Generate theme files for all configured applications.
 * @return {Promise<void>}
 */
async function handleThemeGen() {
  reporter.info('Generating theme files for all applications')

  const tasks = apps.map(app => gen_themes_per_app(app))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(/** @type {(r: PromiseSettledResult<unknown>) => r is PromiseRejectedResult} */ (result => result.status === 'rejected'))
      .map(result => result.reason),
  )

  if (errors.length > 0) {
    reporter.error('Errors encountered:', errors)
  } else {
    reporter.info('Theme files generated successfully')
  }
}

/**
 * Toggle theme between light and dark variants.
 * @param {string} [theme] - Theme name to toggle
 * @return {Promise<void>}
 */
async function handleThemeToggle(theme) {
  const data = await setting.load()
  theme = theme?.toLowerCase() || data.theme
  reporter.info('Toggling theme from:', theme)

  if (!XDG_CONFIG_NODE_ASSET_THEMES.includes(theme)) {
    reporter.error('Cannot find the given theme:', theme)
    return
  }

  /** @type {IThemeScheme|undefined} */
  let scheme = await load_theme_scheme(theme)
  if (!scheme) return

  if (scheme.opposite) {
    theme = `${scheme.theme}-${scheme.opposite}`
    reporter.info('Switching to opposite theme:', theme)
    scheme = await load_theme_scheme(theme)
    if (!scheme) return
  }

  const tasks = apps.map(app => apply_theme_per_app(app, scheme))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(/** @type {(r: PromiseSettledResult<unknown>) => r is PromiseRejectedResult} */ (result => result.status === 'rejected'))
      .map(result => result.reason),
  )

  if (errors.length > 0) {
    reporter.error('Errors encountered:', errors)
  } else {
    data.theme = theme
    await setting.save(data)
    reporter.info('Theme toggled successfully')
  }
}

// ============================================================
// CLI
// ============================================================

if (process.argv[1] === import.meta.filename) {
  const applyCmd = new Command({ name: 'apply', description: 'Apply a theme to all configured applications.' })
    .argument({ name: 'theme', kind: 'optional', description: 'Theme name to apply' })
    .action(async ({ args }) => {
      await handleThemeApply(/** @type {string | undefined} */ (args.theme))
    })

  const genCmd = new Command({ name: 'generate', description: 'Generate theme files for all configured applications.' })
    .action(handleThemeGen)

  const toggleCmd = new Command({ name: 'toggle', description: 'Toggle theme between light and dark variants.' })
    .argument({ name: 'theme', kind: 'optional', description: 'Theme name to toggle' })
    .action(async ({ args }) => {
      await handleThemeToggle(/** @type {string | undefined} */ (args.theme))
    })

  const cmd = new Command({ name: 'theme', description: 'Theme management CLI.', helpSubcommand: true })
    .subcommand('apply', applyCmd)
    .subcommand('generate', genCmd)
    .subcommand('gen', genCmd)
    .subcommand('toggle', toggleCmd)

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
