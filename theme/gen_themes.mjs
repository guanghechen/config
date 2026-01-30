import { apps } from './_config.mjs'
import { gen_themes_per_app } from './_util.mjs'

if (process.argv[1] === import.meta.filename) {
  const tasks = apps.map(app => gen_themes_per_app(app))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(result => result.status === 'rejected')
      .map(result => result.reason || result.message || result.stack || result),
  )

  if (errors.length > 0) {
    console.error('\x1b[31m[gen_themes]\x1b[0m Errors encountered:', errors)
  }
}
