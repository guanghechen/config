import fs from "node:fs";
import path from "node:path";
import {
  HOME_CONFIG,
  HOME_THEME_APP,
  HOME_THEME_SCHEME,
  apps,
  themes,
} from "./util.mjs";

for (const app of apps) {
  if (!app.active(app) || !app.themes) continue;

  const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
  if (!fs.existsSync(template_filepath)) {
    console.error("[gen_theme] Cannot find the template.", { app });
    continue;
  }
  const template = fs.readFileSync(template_filepath, "utf8");

  const theme_home = path.join(HOME_CONFIG, app.name, app.themes);
  for (const theme of themes) {
    const scheme_filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
    if (!fs.existsSync(scheme_filepath)) {
      console.error("[gen_theme] Cannot find the scheme.", { app, theme });
      continue;
    }
    const scheme = fs.readFileSync(scheme_filepath, "utf8");
    const content = app.render(app, template, scheme);

    const theme_filepath = path.resolve(theme_home, `${theme}${app.extname}`);
    fs.mkdirSync(path.dirname(theme_filepath), { recursive: true });
    fs.writeFileSync(theme_filepath, content, "utf8");
  }
}
