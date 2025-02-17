import fs from "node:fs";
import path from "node:path";
import url from "node:url";
import { F_WINDOWS_TERMINAL_SETTINGS } from '../../_shared/env.mjs';

if (F_WINDOWS_TERMINAL_SETTINGS) {
  const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
  const encoding = "utf8";

  const customized_filepath = path.join(__dirname, "settings.json");
  const customized_content = fs.readFileSync(customized_filepath, encoding);
  const customized = JSON.parse(customized_content);

  const raw_content = fs.readFileSync(F_WINDOWS_TERMINAL_SETTINGS, encoding);
  const raw = JSON.parse(raw_content);

  for (const [key, val] of Object.entries(customized)) {
    raw[key] = val;
  }
  const content = JSON.stringify(raw, null, 2);
  fs.writeFileSync(F_WINDOWS_TERMINAL_SETTINGS, content, encoding);
}
