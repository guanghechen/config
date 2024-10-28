#! /usr/bin/env node

import { themes, apps } from "./config.mjs";
import { gen_theme } from "./util.mjs";

for (const app of Object.keys(apps)) {
  for (const theme of themes) {
    gen_theme(app, theme);
  }
}
