#!/usr/bin/env node

/**
 * Generate theme files for all configured applications.
 */

import { Command } from '@guanghechen/stl/commander'
import { Reporter } from '@guanghechen/stl/reporter'
import { apps } from './theme/_config.mjs'
import { gen_themes_per_app } from './theme/_util.mjs'

const reporter = new Reporter({ prefix: 'theme-gen' })

/**
 * @return {Promise<void>}
 */
export async function handleThemeGen() {
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

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command('theme-gen', reporter)
    .description('Generate theme files for all configured applications.')
    .example('theme-gen')
    .example('theme-gen --silent')
    .action(handleThemeGen)

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
