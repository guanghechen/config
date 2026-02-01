#!/usr/bin/env node

/**
 * Toggle theme between light and dark variants.
 */

import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'
import { XDG_CONFIG_NODE_ASSET_THEMES } from '#env/path'
import { settings } from '#env/setting'
import { apps } from './theme/_config.mjs'
import { apply_theme_per_app, load_theme_scheme } from './theme/_util.mjs'

/** @typedef {import("./theme/types.d.ts").IThemeScheme} IThemeScheme */

const reporter = new Reporter({ prefix: 'theme-toggle' })

/**
 * @param {string} [theme] - Theme name to toggle
 * @return {Promise<void>}
 */
export async function handleThemeToggle(theme) {
  const data = await settings.load()
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
    await settings.save(data)
    reporter.info('Theme toggled successfully')
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command('theme-toggle', reporter)
    .description('Toggle theme between light and dark variants.')
    .argument('[theme]', 'Theme name to toggle')
    .example('theme-toggle')
    .example('theme-toggle tokyonight-night')
    .action(async ({ args }) => {
      await handleThemeToggle(/** @type {string | undefined} */ (args.theme))
    })

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
