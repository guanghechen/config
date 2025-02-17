import os from 'node:os'
import path from "node:path";
import url from "node:url";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
export const XDG_CONFIG_HOME = process.env.XDG_CONFIG_HOME || path.normalize(path.join(__dirname, "../../../"));

export const platform = (() => {
  if (os.release().toLowerCase().includes('microsoft')) return 'wsl'
  if (os.platform() === 'win32') return 'win'
  if (os.platform() === 'darwin') return 'mac'
  if (os.platform() === 'linux') return 'nix'
  return 'unknown'
})()

