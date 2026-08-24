#!/usr/bin/env node

/**
 * Theme management CLI with subcommands: apply, gen, toggle.
 */

import { XDG_CONFIG_NODE_ASSET_THEMES } from '#env'
import { Setting } from '#setting'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

import { apps } from './theme/_config.mjs'
import {
  gen_full_theme_name,
  gen_themes_per_app,
  load_theme_scheme,
  prepare_theme_per_app,
} from './theme/_util.mjs'

/** @typedef {import("./theme/types.d.ts").IThemeScheme} IThemeScheme */
/** @typedef {import("./theme/types.d.ts").IReporter} IReporter */
/** @typedef {{ok: true, theme: string, scheme: IThemeScheme} | {ok: false}} IThemeToggleResult */

/** Silent reporter that suppresses all output */
const silentReporter = {
  debug() {},
  info() {},
  warn() {},
  error() {},
}

/**
 * Resolve one opposite-theme transition from the given theme.
 *
 * @param {IReporter} reporter
 * @param {string} theme
 * @param {(reporter: IReporter, theme: string) => Promise<IThemeScheme|undefined>} [loadScheme]
 * @return {Promise<IThemeToggleResult>}
 */
export async function resolveThemeToggle(
  reporter,
  theme,
  loadScheme = load_theme_scheme,
) {
  let scheme = await loadScheme(reporter, theme)
  if (!scheme) return { ok: false }
  theme = gen_full_theme_name(scheme.theme, scheme.variant)

  if (scheme.opposite) {
    theme = `${scheme.theme}-${scheme.opposite}`
    scheme = await loadScheme(reporter, theme)
    if (!scheme) return { ok: false }
  }

  return { ok: true, theme, scheme }
}

/**
 * @param {IReporter} reporter
 * @param {IThemeScheme} scheme
 * @param {typeof apps} [configuredApps]
 * @param {typeof prepare_theme_per_app} [prepareTheme]
 * @return {Promise<boolean>}
 */
export async function applyThemeToApps(
  reporter,
  scheme,
  configuredApps = apps,
  prepareTheme = prepare_theme_per_app,
) {
  const preparedResults = await Promise.allSettled(
    configuredApps.map(app => prepareTheme(reporter, app, scheme)),
  )
  const preparationErrors = preparedResults
    .filter(/** @type {(r: PromiseSettledResult<unknown>) => r is PromiseRejectedResult} */ (result => result.status === 'rejected'))
    .map(result => result.reason)
  if (preparationErrors.length > 0) {
    reporter.error('Errors encountered:', preparationErrors)
    return false
  }

  const preparedApplications = preparedResults
    .filter(/** @type {(r: PromiseSettledResult<() => Promise<void>>) => r is PromiseFulfilledResult<() => Promise<void>>} */ (result => result.status === 'fulfilled'))
    .map(result => result.value)
  const applyResults = await Promise.allSettled(
    preparedApplications.map(apply => apply()),
  )
  const applyErrors = applyResults
    .filter(/** @type {(r: PromiseSettledResult<unknown>) => r is PromiseRejectedResult} */ (result => result.status === 'rejected'))
    .map(result => result.reason)

  if (applyErrors.length === 0) return true
  reporter.error('Errors encountered:', applyErrors)
  return false
}

// ============================================================
// Handlers
// ============================================================

/**
 * Apply a theme to all configured applications.
 * @param {IReporter} reporter
 * @param {string} [theme] - Theme name to apply
 * @return {Promise<boolean>}
 */
async function handleThemeApply(reporter, theme) {
  const setting = new Setting({ reporter })
  const data = await setting.load()
  theme = theme?.toLowerCase() || data.theme
  reporter.info('Applying theme:', theme)

  if (!XDG_CONFIG_NODE_ASSET_THEMES.includes(theme)) {
    reporter.error('Cannot find the given theme:', theme)
    return false
  }

  /** @type {IThemeScheme|undefined} */
  const scheme = await load_theme_scheme(reporter, theme)
  if (!scheme) return false
  if (!await applyThemeToApps(reporter, scheme)) return false

  data.theme = theme
  await setting.save(data)
  reporter.info('Theme applied successfully')
  return true
}

/**
 * Generate theme files for all configured applications.
 * @param {IReporter} reporter
 * @return {Promise<void>}
 */
async function handleThemeGen(reporter) {
  reporter.info('Generating theme files for all applications')

  const tasks = apps.map(app => gen_themes_per_app(reporter, app))
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
 * Toggle from the current or specified theme to its opposite.
 * @param {IReporter} reporter
 * @param {string} [theme] - Theme name to toggle
 * @return {Promise<boolean>}
 */
async function handleThemeToggle(reporter, theme) {
  const setting = new Setting({ reporter })
  const data = await setting.load()
  theme = theme?.toLowerCase() || data.theme
  reporter.info('Toggling theme from:', theme)

  if (!XDG_CONFIG_NODE_ASSET_THEMES.includes(theme)) {
    reporter.error('Cannot find the given theme:', theme)
    return false
  }

  const sourceTheme = theme
  const resolved = await resolveThemeToggle(reporter, sourceTheme)
  if (!resolved.ok) return false
  const { theme: targetTheme, scheme } = resolved
  if (targetTheme !== sourceTheme) {
    reporter.info('Switching to opposite theme:', targetTheme)
  }

  if (!await applyThemeToApps(reporter, scheme)) return false

  data.theme = targetTheme
  await setting.save(data)
  reporter.info('Theme toggled successfully')
  return true
}

// ============================================================
// CLI
// ============================================================

if (process.argv[1] === import.meta.filename) {
  // Check for --silent flag early and filter it from argv
  const rawArgv = process.argv.slice(2)
  const isSilent = rawArgv.includes('--silent') || rawArgv.includes('-s')
  const argv = rawArgv.filter(arg => arg !== '--silent' && arg !== '-s')
  const reporter = isSilent ? silentReporter : new Reporter({ prefix: 'theme' })

  const applyCmd = new Command({ name: 'apply', description: 'Apply a theme to all configured applications.' })
    .argument({ name: 'theme', kind: 'optional', description: 'Theme name to apply' })
    .action(async ({ args }) => {
      const succeeded = await handleThemeApply(
        reporter,
        /** @type {string | undefined} */ (args.theme),
      )
      if (!succeeded) process.exitCode = 1
    })

  const genCmd = new Command({ name: 'generate', description: 'Generate theme files for all configured applications.' })
    .action(async () => {
      await handleThemeGen(reporter)
    })

  const toggleCmd = new Command({ name: 'toggle', description: 'Toggle to the opposite theme.' })
    .argument({ name: 'theme', kind: 'optional', description: 'Theme name to toggle' })
    .action(async ({ args }) => {
      const succeeded = await handleThemeToggle(
        reporter,
        /** @type {string | undefined} */ (args.theme),
      )
      if (!succeeded) process.exitCode = 1
    })

  const cmd = new Command({ name: 'theme', description: 'Theme management CLI.', help: true })
    .option({ long: 'silent', short: 's', type: 'boolean', description: 'Suppress all output' })
    .subcommand('apply', applyCmd)
    .subcommand('generate', genCmd)
    .subcommand('gen', genCmd)
    .subcommand('toggle', toggleCmd)

  await cmd.run({ argv, envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
