import { apps } from "./_config.mjs";
import { themes } from "./_env.mjs";
import { apply_theme_per_app, load_theme_scheme } from "./_util.mjs";

await handle();

async function handle() {
  const theme = process.argv[2]?.toLowerCase();
  if (!themes.includes(theme)) {
    console.error("[apply_theme] Cannot find the given theme:", theme);
    return;
  }

  const scheme = await load_theme_scheme(theme);
  if (scheme) {
    const tasks = apps.map((app) => apply_theme_per_app(theme, scheme, app));
    await Promise.allSettled(tasks);
  }
}
