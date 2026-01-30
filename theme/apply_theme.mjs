import { XDG_CONFIG_NODE_THEMES } from '../env/path.mjs'
import { settings } from '../env/setting.mjs'
import { Reporter } from '../util/reporter.mjs'
import { apps } from './_config.mjs'
import { apply_theme_per_app, load_theme_scheme } from './_util.mjs'

/** @typedef {import("./_types.mjs").IThemeScheme} IThemeScheme */

const reporter = new Reporter('apply_theme')

if (process.argv[1] === import.meta.filename) {
  await handle()
}

/**
 * @return {Promise<void>}
 */
async function handle() {
  const data = await settings.load()
  const theme = process.argv[2]?.toLowerCase() || data.theme
  if (!XDG_CONFIG_NODE_THEMES.includes(theme)) {
    reporter.error('Cannot find the given theme:', theme)
    return
  }

  /** @type {IThemeScheme|undefined} */
  const scheme = await load_theme_scheme(theme)
  if (!scheme) return

  const tasks = apps.map(app => apply_theme_per_app(app, scheme))
  const errors = await Promise.allSettled(tasks).then(results =>
    results
      .filter(result => result.status === 'rejected')
      .map(result => result.reason || result.message || result.stack || result),
  )

  if (errors.length > 0) {
    reporter.error('Errors encountered:', errors)
  } else {
    data.theme = theme
    await settings.save(data)
  }
}
