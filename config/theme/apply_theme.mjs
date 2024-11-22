import { existsSync, mkdirSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import {
  HOME_CONFIG,
  HOME_THEME_APP,
  HOME_THEME_SCHEME,
  apps,
  themes,
} from "./util.mjs";

const theme = process.argv[2]?.toLowerCase();
if (themes.includes(theme)) {
  const tasks = apps.map((app) => apply_theme_per_app(theme, app));
  await Promise.allSettled(tasks);
} else {
  console.error("[toggle_theme] Cannot find the given theme:", theme);
}

/**
 * @param {string}      theme
 * @param {IAppConfig}  app
 * @return {Promise<void>}
 */
async function apply_theme_per_app(theme, app) {
  if (!app.active(app)) return;

  if (app.local) {
    const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
    if (!existsSync(template_filepath)) {
      console.error("[gen_theme] Cannot find the template.", { app });
      return;
    }
    const template = await fs.readFile(template_filepath, "utf8");

    const scheme_filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
    if (!existsSync(scheme_filepath)) {
      console.error("[gen_theme] Cannot find the scheme.", { app, theme });
      return;
    }
    const scheme = await fs.readFile(scheme_filepath, "utf8");
    const content = app.render(app, template, scheme);

    const theme_filepath = path.resolve(HOME_CONFIG, app.name, app.local);
    mkdirSync(path.dirname(theme_filepath), { recursive: true });
    await fs.writeFile(theme_filepath, content, "utf8");
  }

  await app.after_apply?.(app, theme);
}
