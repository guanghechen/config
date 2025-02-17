import fs from "node:fs";
import os from 'node:os'
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const __XDG_CONFIG_HOME = process.env.XDG_CONFIG_HOME || path.normalize(path.join(__dirname, "../../../"));
const __F_WINDOWS_TERMINAL_SETTINGS = process.env.f_windows_terminal_settings
const __F_VSCODE_SETTINGS = process.env.f_vscode_settings

export const XDG_CONFIG_HOME = __XDG_CONFIG_HOME
export const F_WINDOWS_TERMINAL_SETTINGS = fs.existsSync(__F_WINDOWS_TERMINAL_SETTINGS) ? __F_WINDOWS_TERMINAL_SETTINGS : null
export const F_VSCODE_SETTINGS = fs.existsSync(__F_VSCODE_SETTINGS) ? __F_VSCODE_SETTINGS : null

export const platform = (() => {
  if (os.release().toLowerCase().includes('microsoft')) return 'wsl'
  if (os.platform() === 'win32') return 'win'
  if (os.platform() === 'darwin') return 'mac'
  if (os.platform() === 'linux') return 'nix'
  return 'unknown'
})()

