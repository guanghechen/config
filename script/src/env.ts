import { existsSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import url from "node:url"

export type IPlatform = "wsl" | "win" | "osx" | "nix" | "unknown"

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

function existsOrNull(envVar: string | undefined): string | null {
  return envVar && existsSync(envVar) ? envVar : null
}

function detectPlatform(): IPlatform {
  if (os.release().toLowerCase().includes("microsoft")) return "wsl"
  if (os.platform() === "win32") return "win"
  if (os.platform() === "darwin") return "osx"
  if (os.platform() === "linux") return "nix"
  return "unknown"
}

export const XDG_CONFIG_HOME =
  process.env.XDG_CONFIG_HOME || path.normalize(path.join(__dirname, "../../"))
export const USER_HOME =
  process.env.HOME || process.env.USERPROFILE || path.dirname(XDG_CONFIG_HOME)
export const GEMINI_CONFIG_DIR = process.env.GEMINI_CONFIG_DIR || path.join(USER_HOME, ".gemini")
export const F_WINDOWS_TERMINAL_SETTINGS = existsOrNull(process.env.f_windows_terminal_settings)
export const F_VSCODE_KEYBINDINGS = existsOrNull(process.env.f_vscode_keybindings)
export const platform = detectPlatform()
