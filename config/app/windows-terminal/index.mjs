import fs from "node:fs";
import path from "node:path";
import url from "node:url";

const filepath = process.env.f_windows_terminal_settings;
if (fs.existsSync(filepath)) {
  const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
  const encoding = "utf8";

  const customized_filepath = path.join(__dirname, "windows-terminal.json");
  const customized_content = fs.readFileSync(customized_filepath, encoding);
  const customized = JSON.parse(customized_content);

  const raw_content = fs.readFileSync(filepath, encoding);
  const raw = JSON.parse(raw_content);

  for (const [key, val] of Object.entries(customized)) {
    raw[key] = val;
  }
  const content = JSON.stringify(raw, null, 2);
  fs.writeFileSync(filepath, content, encoding);
}
