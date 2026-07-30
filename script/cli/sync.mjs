#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { chmod, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// config.shared.toml owns the prefix, while the first divider and everything
// after it is host-local state that must remain byte-for-byte identical.
// Refuse undivided configs instead of guessing that ownership boundary.
export const DIVIDER = "#".repeat(100);
// Exclude the line ending so slicing at match.index also preserves the divider.
const DIVIDER_RE = new RegExp(`^${DIVIDER}(?=\\r?$)`, "m");
const DEFAULT_CONFIG_MODE = 0o600;
const SPECIAL_SYMBOL_RE = /^\$\{([A-Z][A-Z0-9_]*)\}/u;

// Keep environment access explicit: shared config templates must not become
// arbitrary environment-variable interpolation, which could expose secrets.
const SPECIAL_SYMBOLS = new Map([
  ["HOME", ({ platform }) => platform === "win32" ? "USERPROFILE" : "HOME"],
  ["CODEX_HOME", () => "CODEX_HOME"],
]);

const scriptPath = fileURLToPath(import.meta.url);
const defaultCodexHome = path.resolve(path.dirname(scriptPath), "../..");

async function main() {
  const localConfigPath = await syncConfig();
  console.log(`updated ${localConfigPath}`);
}

export async function syncConfig({
  codexHome = defaultCodexHome,
  renderedSharedConfig,
} = {}) {
  const resolvedCodexHome = path.resolve(codexHome);
  const sharedConfigPath = path.join(resolvedCodexHome, "config.shared.toml");
  const localConfigPath = path.join(resolvedCodexHome, "config.toml");
  const [sharedConfig, existingConfig] = await Promise.all([
    renderedSharedConfig === undefined
      ? readFile(sharedConfigPath, "utf8").then((source) => renderSharedConfig(source))
      : renderedSharedConfig,
    readOptionalFile(localConfigPath),
  ]);
  const preservedSuffix = existingConfig === null
    ? `${DIVIDER}\n\n`
    : localConfigSuffix(existingConfig, localConfigPath);
  const nextConfig = `${trimTrailingNewlines(sharedConfig)}\n\n${preservedSuffix}`;

  await writeAtomic(localConfigPath, nextConfig);
  return localConfigPath;
}

export function renderSharedConfig(
  source,
  { environment = process.env, platform = process.platform } = {},
) {
  // Scan the source instead of parse/serialize so comments, ordering, and
  // formatting remain untouched while replacements stay TOML-string aware.
  let quote = null;
  let inComment = false;
  let unchangedStart = 0;
  let rendered = "";

  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];

    if (inComment) {
      if (char === "\n") {
        inComment = false;
      }
      continue;
    }

    if (quote === null) {
      if (char === "#") {
        inComment = true;
        continue;
      }
      const openingQuote = quoteAt(source, index);
      if (openingQuote) {
        quote = openingQuote;
        index += openingQuote.length - 1;
        continue;
      }
    } else {
      if (quote.startsWith('"') && char === "\\") {
        index += 1;
        continue;
      }
      const closingQuoteLength = quoteRunLength(source, index, quote);
      if (closingQuoteLength > 0) {
        index += closingQuoteLength - 1;
        quote = null;
        continue;
      }
    }

    if (char !== "$") {
      continue;
    }
    const symbolMatch = source.slice(index).match(SPECIAL_SYMBOL_RE);
    const environmentKeyFor = SPECIAL_SYMBOLS.get(symbolMatch?.[1]);
    if (!environmentKeyFor) {
      continue;
    }
    if (quote === null) {
      throw new Error(`${symbolMatch[0]} must appear inside a TOML string`);
    }

    const environmentKey = environmentKeyFor({ platform });
    const value = environment[environmentKey];
    if (typeof value !== "string" || value.length === 0) {
      throw new Error(`cannot expand ${symbolMatch[0]}: ${environmentKey} is not set`);
    }

    rendered += source.slice(unchangedStart, index);
    rendered += renderSymbolValue(value, quote, symbolMatch[0], environmentKey);
    unchangedStart = index + symbolMatch[0].length;
    index = unchangedStart - 1;
  }

  return rendered + source.slice(unchangedStart);
}

function quoteAt(source, index) {
  for (const quote of ['"""', "'''", '"', "'"]) {
    if (source.startsWith(quote, index)) {
      return quote;
    }
  }
  return null;
}

function quoteRunLength(source, index, quote) {
  if (quote.length === 1) {
    return source.startsWith(quote, index) ? 1 : 0;
  }
  if (source[index] !== quote[0]) {
    return 0;
  }

  let length = 1;
  while (source[index + length] === quote[0]) {
    length += 1;
  }
  return length >= quote.length ? length : 0;
}

function renderSymbolValue(value, quote, symbol, environmentKey) {
  if (quote.startsWith('"')) {
    return JSON.stringify(value).slice(1, -1);
  }

  const invalidLiteralValue = quote === "'"
    ? value.includes("'") || /[\r\n]/u.test(value)
    : value.includes("'''");
  if (invalidLiteralValue) {
    throw new Error(
      `cannot expand ${symbol} from ${environmentKey} safely inside a TOML literal string`,
    );
  }
  return value;
}

async function readOptionalFile(filePath) {
  try {
    return await readFile(filePath, "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

function localConfigSuffix(existingConfig, localConfigPath) {
  const dividerMatch = existingConfig.match(DIVIDER_RE);
  if (!dividerMatch) {
    // Guessing this ownership boundary could overwrite local-only configuration.
    throw new Error(
      `${localConfigPath} does not contain a line of exactly 100 '#' characters`,
    );
  }

  const suffix = existingConfig.slice(dividerMatch.index);
  if (
    !suffix.startsWith(`${DIVIDER}\n\n`)
    && !suffix.startsWith(`${DIVIDER}\r\n\r\n`)
  ) {
    throw new Error(`the first divider in ${localConfigPath} must be followed by a blank line`);
  }
  return suffix;
}

function trimTrailingNewlines(value) {
  return value.replace(/(?:\r?\n)+$/u, "");
}

export async function writeAtomic(filePath, contents) {
  // A sibling temporary file keeps rename on the same filesystem and atomic.
  const tmpPath = `${filePath}.${process.pid}.${randomUUID()}.tmp`;
  const mode = await targetMode(filePath);

  try {
    await writeFile(tmpPath, contents, { mode });
    // File creation applies umask; restore the target's exact mode before replacement.
    await chmod(tmpPath, mode);
    await rename(tmpPath, filePath);
  } catch (error) {
    try {
      await rm(tmpPath, { force: true });
    } catch (cleanupError) {
      throw new AggregateError(
        [error, cleanupError],
        `failed to update ${filePath} and remove temporary file ${tmpPath}`,
      );
    }
    throw error;
  }
}

async function targetMode(filePath) {
  try {
    return (await stat(filePath)).mode & 0o7777;
  } catch (error) {
    if (error?.code === "ENOENT") {
      return DEFAULT_CONFIG_MODE;
    }
    throw error;
  }
}

if (path.resolve(process.argv[1] || "") === scriptPath) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
