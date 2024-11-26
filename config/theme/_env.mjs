import { readdirSync } from "node:fs";
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const cwd = __dirname;
export const HOME_THEME_SCHEME = path.join(__dirname, "scheme");
export const HOME_THEME_APP = path.join(__dirname, "app");
export const HOME_CONFIG =
  process.env.XDG_CONFIG_HOME ||
  (process.env.HOME ? path.join(process.env.HOME, ".config") : "");
export const themes = readdirSync(HOME_THEME_SCHEME).map((p) =>
  p.replace(/\.json$/, ""),
);
