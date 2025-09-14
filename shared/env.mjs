import { existsSync, statSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const WORKSPACE_DIR = path.dirname(__dirname);

/**
 * @param {string} content
 * @param {?Record<string, string|number|boolean|null>} env
 * @returns {Record<string, string|number|boolean|null>}
 */
function parse(content, env) {
  if (!content) return {};

  env = env || {};
  const text = content.replace(/\r\n?/gm, "\n");

  const regex =
    /(?:^|^)\s*(?:export\s+)?([\w.-]+)(?:\s*=\s*?|:\s+?)(\s*'(?:\\'|[^'])*'|\s*"(?:\\"|[^"])*"|\s*`(?:\\`|[^`])*`|[^#\r\n]+)?\s*(?:#.*)?(?:$|$)/gm;

  while (true) {
    const match = regex.exec(text);
    if (!match) break;

    const key = match[1];
    let val = match[2]?.trim() || "";

    // Check if double quoted
    const hasQuote = val[0] === '"' || val[0] === "'";

    // Remove surrounding quotes
    val = val.replace(/^(['"`])([\s\S]*)\1$/gm, "$2");

    // Expand newlines if double quoted
    if (hasQuote) {
      val = val //
        .replace(/\\n/g, "\n")
        .replace(/\\r/g, "\r");
    }

    if (!hasQuote) {
      if (val === "null") {
        env[key] = null;
        continue;
      }

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
    }

    env[key] = val;
  }

  return env;
}

/**
 * @param {string} filepath
 * @param {Record<string, string|number|boolean|null>} env
 * @returns {Promise<void>}
 */
async function load(filepath, env) {
  if (!existsSync(filepath) || !statSync(filepath).isFile()) return;

  const content = await fs.readFile(filepath, "utf8");
  parse(content, env);
}

/**
 * @param {string} from
 * @param {string} to
 * @param {?Record<string, string|number|boolean|null>} env
 * @returns {Promise<Record<string, unknown>>}
 */
async function loads(from, to, env) {
  const pieces = path.relative(from, to).split(/[/\\]+/g);
  if (pieces.length < 1 || !!pieces[0]) pieces.unshift("");

  env = env || {};

  let p = from;
  for (const piece of pieces) {
    p = path.join(p, piece);
    const e1 = path.join(p, ".env");
    const e2 = path.join(p, ".env.local");
    await load(e1, env);
    await load(e2, env);
  }

  return env;
}

export const envParser = { load, loads, parse };
