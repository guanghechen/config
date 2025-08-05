import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { XDG_CONFIG_HOME } from "./env.mjs";

/**
 * @typedef {Object} Settings
 * @property {string} theme - The theme name
 */

const filepath = path.resolve(XDG_CONFIG_HOME, "guanghechen/.setting.json");

/**
 * Get default settings
 * @returns {Settings} Default settings object
 */
function defaults() {
  return {
    theme: "gruvbox-dark",
  };
}

/**
 * Normalize settings data
 * @param {unknown} data - The input data to normalize
 * @returns {Settings} Normalized settings object
 */
function normalize(data) {
  const resolved = defaults();
  if (!data || typeof data !== "object") return resolved;
  if (typeof data.theme === "string") resolved.theme = data.theme;
  return resolved;
}

export const settings = {
  /**
   * Load settings from config file
   * @returns {Promise<Settings>} The loaded settings
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
      console.error("[get_config] failed to load the filepath.", { filepath });
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
