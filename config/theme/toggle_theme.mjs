#! /usr/bin/env node

import { apps, themes } from "./config.mjs";
import { toggle_theme } from "./util.mjs";

const theme = process.argv[2]?.toLowerCase();
if (!themes.includes(theme)) {
  console.error("[toggle_theme] Cannot find the given theme:", theme);
} else {
  for (const app of Object.keys(apps)) {
    toggle_theme(app, theme);
  }
}
