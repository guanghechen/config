#!/usr/bin/env node

/**
 * Apply a theme to all configured applications.
 */

import { XDG_CONFIG_NODE_ASSET_THEMES, XDG_CONFIG_NODE_SETTING } from '#env'
import { Setting } from '#setting'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

import { apps } from './theme/_config.mjs'
import { apply_theme_per_app, load_theme_scheme } from './theme/_util.mjs'

/** @typedef {import("./theme/types.d.ts").IThemeScheme} IThemeScheme */

const reporter = new Reporter({ prefix: 'theme-apply' })
const setting = new Setting({ filepath: XDG_CONFIG_NODE_SETTING, reporter })

/**
 * @param {string} [theme] - Theme name to apply
 * @return {Promise<void>}
 */
export async function handleThemeApply(theme) {
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

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'theme-apply', description: 'Apply a theme to all configured applications.' })
    .argument({ name: 'theme', kind: 'optional', description: 'Theme name to apply' })
    .action(async ({ args }) => {
      await handleThemeApply(/** @type {string | undefined} */ (args.theme))
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
