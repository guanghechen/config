import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { XDG_CONFIG_HOME, platform } from "./env.mjs";

/**
 * @typedef {Object} ISettings
 * @property {string} theme - The theme name
 * @property {string} edition - The edition name
 */

const filepath = path.resolve(XDG_CONFIG_HOME, "guanghechen/.setting.json");
const VALID_EDITIONS = new Set(["nix", "nix-remote", "osx", "win"]);

function isValidEdition(value) {
  return typeof value === "string" && VALID_EDITIONS.has(value);
}

function resolveEditionFromPlatform() {
  const fallbackEdition = platform === "wsl" ? "nix" : platform;
  return isValidEdition(fallbackEdition) ? fallbackEdition : "nix";
}

function extractEditionFromArgs(args) {
  const flagIndex = args.findIndex((arg) => arg === "--sync-edition");
  if (flagIndex !== -1 && args[flagIndex + 1]) return args[flagIndex + 1];
  const withValue = args.find((arg) => arg.startsWith("--sync-edition="));
  if (!withValue) return null;
  return withValue.slice("--sync-edition=".length);
}

/**
 * Get default settings
 * @returns {ISettings} Default settings object
 */
function defaults() {
  return {
    edition: resolveEditionFromPlatform(),
    theme: "gruvbox-dark",
  };
}

/**
 * Normalize settings data
 * @param {unknown} data - The input data to normalize
 * @returns {ISettings} Normalized settings object
 */
function normalize(data) {
  const resolved = defaults();
  if (!data || typeof data !== "object") return resolved;
  if (typeof data.edition === "string" && isValidEdition(data.edition)) {
    resolved.edition = data.edition;
  }
  if (typeof data.theme === "string") resolved.theme = data.theme;
  return resolved;
}

export const settings = {
  /**
   * Load settings from config file
   * @returns {Promise<ISettings>} The loaded settings
   */
  async load() {
    if (!existsSync(filepath)) {
      return defaults();
    }

    try {
      const content = await fs.readFile(filepath, "utf8");
      const json = JSON.parse(content);
      return normalize(json);
    } catch (error) {
      console.error("\x1b[31m[settings.load]\x1b[0m Failed to load the filepath.", { filepath });
      return defaults();
    }
  },

  /**
   * Save settings to config file
   * @param {unknown} next_data - The settings data to save
   * @returns {Promise<void>}
   */
  async save(next_data) {
    const data = normalize(next_data);
    const content = JSON.stringify(data, null, 2);
    await fs.writeFile(filepath, content, "utf8");
  },
};

export async function syncEdition(edition) {
  const data = await settings.load();
  data.edition = isValidEdition(edition) ? edition : resolveEditionFromPlatform();
  await settings.save(data);
}

const selfPath = fileURLToPath(import.meta.url);
const isDirectRun = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(selfPath);
if (isDirectRun) {
  const edition = extractEditionFromArgs(process.argv.slice(2));
  if (edition !== null) {
    await syncEdition(edition);
  }
}
