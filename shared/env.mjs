import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const WORKSPACE_DIR = path.dirname(__dirname);

const regexes = {
  lf: /\n+/g,
  assign: /^([\w]+)=([\w\W]+)$/,
  string: /^['"][\s\S]*\1$/,
};

/**
 *
 * @param {string} text
 * @returns {Record<string, string|number|boolean>}
 */
function parse(text) {
  const env = {};

  const lines = text
    .trim()
    .split(regexes.lf)
    .map((line) => line.trim())
    .filter((line) => !line || !line.startsWith("#") || !line.startsWith("//"));

  for (const line of lines) {
    const m = regexes.assign.exec(line);
    if (!m) continue;

    const [_, key, val] = m;

    if (val === "false") {
      env[key] = false;
      continue;
    }

    if (val === "true") {
      env[key] = true;
      continue;
    }

    const n = Number(val);
    if (!Number.isNaN(n)) {
      env[key] = n;
      continue;
    }

    if (regexes.string.test(val)) {
      env[key] = val.slice(1, -1);
      continue;
    }

    env[key] = val;
  }

  return env;
}

export const envParser = { parse };
