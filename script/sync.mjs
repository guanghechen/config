#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { chmod, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Unlike setup.mjs, this command never migrates or regenerates local state:
// config.shared.toml owns the prefix, while the first divider and everything
// after it must remain byte-for-byte identical.
export const DIVIDER = "#".repeat(100);
// Exclude the line ending so slicing at match.index also preserves the divider.
const DIVIDER_RE = new RegExp(`^${DIVIDER}(?=\\r?$)`, "m");
const DEFAULT_CONFIG_MODE = 0o600;

const scriptPath = fileURLToPath(import.meta.url);
const defaultCodexHome = path.resolve(path.dirname(scriptPath), "..");

async function main() {
  const localConfigPath = await syncConfig();
  console.log(`updated ${localConfigPath}`);
}

export async function syncConfig({ codexHome = defaultCodexHome } = {}) {
  const resolvedCodexHome = path.resolve(codexHome);
  const sharedConfigPath = path.join(resolvedCodexHome, "config.shared.toml");
  const localConfigPath = path.join(resolvedCodexHome, "config.toml");
  const [sharedConfig, existingConfig] = await Promise.all([
    readFile(sharedConfigPath, "utf8"),
    readOptionalFile(localConfigPath),
  ]);
  const preservedSuffix = existingConfig === null
    ? `${DIVIDER}\n\n`
    : localConfigSuffix(existingConfig, localConfigPath);
  const nextConfig = `${trimTrailingNewlines(sharedConfig)}\n\n${preservedSuffix}`;

  await writeAtomic(localConfigPath, nextConfig);
  return localConfigPath;
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
