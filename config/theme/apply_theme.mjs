import { settings } from "../_shared/setting.mjs";
import { apps } from "./_config.mjs";
import { themes } from "./_env.mjs";
import { apply_theme_per_app, load_theme_scheme } from "./_util.mjs";

await handle();

/**
 * @return {Promise<void>}
 */
async function handle() {
  const data = await settings.load();
  const theme = process.argv[2]?.toLowerCase() || data.theme;
  if (!themes.includes(theme)) {
    console.error("[apply_theme] Cannot find the given theme:", theme);
    return;
  }

  /** @type {import('./_env.mjs').IThemeScheme|undefined} */
  const scheme = await load_theme_scheme(theme);
  if (!scheme) return;

  const tasks = apps.map((app) => apply_theme_per_app(app, scheme));
  const errors = await Promise.allSettled(tasks).then((results) =>
    results
      .filter((result) => result.status === "rejected")
      .map(
        (result) => result.reason || result.message || result.stack || result,
      ),
  );

  if (errors.length > 0) {
    console.error("[apply_theme] Errors encountered:", errors);
  } else {
    data.theme = theme;
    await settings.save(data);
  }
}
