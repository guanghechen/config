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

const tasks = apps.map((app) => gen_themes_per_app(app));
await Promise.allSettled(tasks);

/**
 * @param {IAppConfig}  app
 * @return {Promise<void>}
 */

async function gen_themes_per_app(app) {
  if (!app.active(app) || !app.themes) return;

  const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
  if (!existsSync(template_filepath)) {
    console.error("[gen_theme] Cannot find the template.", { app });
    return;
  }
  const template = await fs.readFile(template_filepath, "utf8");

  const THEME_HOME = path.join(HOME_CONFIG, app.name, app.themes);
  const tasks_gen_theme = themes.map((theme) => gen_theme(theme));
  await Promise.allSettled(tasks_gen_theme);

  /**
   * @param {string}      theme
   * @return {Promise<void>}
   */
  async function gen_theme(theme) {
    const scheme_filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
    if (!existsSync(scheme_filepath)) {
      console.error("[gen_theme] Cannot find the scheme.", { app, theme });
      return;
    }
    const scheme = await fs.readFile(scheme_filepath, "utf8");
    const content = app.render(app, template, scheme);

    const theme_filepath = path.resolve(THEME_HOME, `${theme}${app.extname}`);
    mkdirSync(path.dirname(theme_filepath), { recursive: true });
    await fs.writeFile(theme_filepath, content, "utf8");
  }
}
