import { Reporter } from '../util/reporter.mjs'
import { apps } from './theme/_config.mjs'
import { gen_themes_per_app } from './theme/_util.mjs'

const reporter = new Reporter('theme-gen')

/**
 * @return {Promise<void>}
 */
export async function handleThemeGen() {
  const tasks = apps.map(app => gen_themes_per_app(app))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(result => result.status === 'rejected')
      .map(result => result.reason || result.message || result.stack || result),
  )

  if (errors.length > 0) {
    reporter.error('Errors encountered:', errors)
  }
}

if (process.argv[1] === import.meta.filename) {
  await handleThemeGen()
}
