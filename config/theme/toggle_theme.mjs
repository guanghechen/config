import { apps } from "./_config.mjs";
import { themes } from "./_env.mjs";
import { apply_theme_per_app, load_theme_scheme } from "./_util.mjs";

await handle();

async function handle() {
  let theme = process.argv[2]?.toLowerCase();
  if (!themes.includes(theme)) {
    console.error("[toggle_theme] Cannot find the given theme:", theme);
    return;
  }

  let scheme = await load_theme_scheme(theme);
  if (!scheme) return;

  const scheme_data = JSON.parse(scheme);
  if (scheme_data.opposite && scheme_data.opposite !== theme) {
    theme = scheme_data.opposite;
    scheme = await load_theme_scheme(theme);
  }

  if (scheme) {
    const tasks = apps.map((app) => apply_theme_per_app(theme, scheme, app));
    await Promise.allSettled(tasks);
  }
}
