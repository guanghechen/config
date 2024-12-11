import { apps } from "./_config.mjs";
import { themes } from "./_env.mjs";
import { apply_theme_per_app, load_theme_scheme } from "./_util.mjs";

await handle();

/**
 * @return {Promise<void>}
 */
async function handle() {
  const theme = process.argv[2]?.toLowerCase();
  if (!themes.includes(theme)) {
    console.error("[apply_theme] Cannot find the given theme:", theme);
    return;
  }

  /** @type {import('./_env.mjs').IThemeScheme|undefined} */
  const scheme = await load_theme_scheme(theme);
  if (!scheme) return;

  const tasks = apps.map((app) => apply_theme_per_app(app, scheme));
  await Promise.allSettled(tasks);
}
