import { execSync } from "node:child_process"
import { existsSync, realpathSync } from "node:fs"
import { dirname, join } from "node:path"
import * as env from "../env"

export function getCliPath(): string | null {
  const isNativeWindows = env.platform === "win"

  try {
    const cmd = isNativeWindows ? "where.exe claude" : "which claude"
    const which = execSync(cmd, { encoding: "utf-8" }).trim().split(/\r?\n/)[0]

    if (isNativeWindows) {
      const cliJs = join(dirname(which), "node_modules", "@anthropic-ai", "claude-code", "cli.js")
      return existsSync(cliJs) ? cliJs : null
    }

    return realpathSync(which)
  } catch {
    return null
  }
}
