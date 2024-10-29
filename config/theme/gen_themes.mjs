#! /usr/bin/env node

import { themes, apps } from "./config.mjs";
import { gen_and_save_theme } from "./util.mjs";

for (const app of Object.keys(apps)) {
  if (app === "windows_terminal") continue;

  for (const theme of themes) {
    await gen_and_save_theme(app, theme);
  }
}
