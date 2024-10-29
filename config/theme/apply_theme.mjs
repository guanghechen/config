import fs from "node:fs";
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
  await apply_theme(theme);
} else {
  console.error("[toggle_theme] Cannot find the given theme:", theme);
}

/**
 * @param {string} theme
 * @return {Promise<void>}
 */
async function apply_theme(theme) {
  for (const app of apps) {
    if (!app.active(app) || !app.local) continue;

    const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
    if (!fs.existsSync(template_filepath)) {
      console.error("[gen_theme] Cannot find the template.", { app });
      continue;
    }
    const template = fs.readFileSync(template_filepath, "utf8");

    const scheme_filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
    if (!fs.existsSync(scheme_filepath)) {
      console.error("[gen_theme] Cannot find the scheme.", { app, theme });
      continue;
    }
    const scheme = fs.readFileSync(scheme_filepath, "utf8");
    const content = app.render(app, template, scheme);

    const theme_filepath = path.resolve(HOME_CONFIG, app.name, app.local);
    fs.mkdirSync(path.dirname(theme_filepath), { recursive: true });
    fs.writeFileSync(theme_filepath, content, "utf8");

    await app.on_apply?.(app);
  }
}
