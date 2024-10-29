#! /usr/bin/env node

import { apps, themes } from "./config.mjs";
import { toggle_theme, toggle_theme_windows_terminal } from "./util.mjs";

const theme = process.argv[2]?.toLowerCase();
if (!themes.includes(theme)) {
  console.error("[toggle_theme] Cannot find the given theme:", theme);
} else {
  for (const app of Object.keys(apps)) {
    if (app === "windows_terminal") {
      await toggle_theme_windows_terminal(theme);
    } else {
      await toggle_theme(app, theme);
    }
  }
}
