import { readFileSync, realpathSync } from "node:fs"
import path from "node:path"

const SAFE_ENV_TEMPLATE_PATTERN = /^\.env\.(?:example|sample|template)$/

export const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env(?:$|\.)/,
  /^\.git-credentials$/,
  /^auth\.json$/,
]

export const SENSITIVE_PATHS = [
  /(?:^|[\\/])\.ssh(?:[\\/]|$)/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

function matchesSensitivePath(filepath) {
  const normalized = process.platform === "win32" ? filepath.toLowerCase() : filepath
  const base = path.basename(normalized)
  if (SENSITIVE_PATHS.some((pattern) => pattern.test(normalized))) return true
  if (SAFE_ENV_TEMPLATE_PATTERN.test(base)) return false
  return SENSITIVE_PATTERNS.some((pattern) => pattern.test(base))
}

function resolveExistingParent(filepath) {
  const suffix = []
  let ancestor = filepath
  while (true) {
    try {
      return path.join(realpathSync.native(ancestor), ...suffix)
    } catch (error) {
      if (!["ENOENT", "ENOTDIR"].includes(error.code)) return null
      const parent = path.dirname(ancestor)
      if (parent === ancestor) return null
      suffix.unshift(path.basename(ancestor))
      ancestor = parent
    }
  }
}

export function isSensitiveFile(filepath, cwd = process.cwd()) {
  if (typeof filepath !== "string" || filepath.length === 0) return false
  if (matchesSensitivePath(path.resolve(cwd, filepath))) return true
  // Keep dot segments for realpath: a symlink followed by '..' must be resolved
  // by the filesystem before normalization. Missing leaves use their nearest
  // existing parent, so creating a file through a directory alias is checked.
  const absolute = path.isAbsolute(filepath) ? filepath : `${cwd}${path.sep}${filepath}`
  const resolved = resolveExistingParent(absolute)
  return resolved !== null && matchesSensitivePath(resolved)
}

export function readPreToolUseInput(toolName) {
  try {
    const input = JSON.parse(readFileSync(0, "utf-8"))
    if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error()
    if (typeof input.tool_name !== "string") throw new Error()
    if (input.tool_name !== toolName) return null
    if (typeof input.tool_input?.command !== "string") throw new Error()
    // Prefer a per-call directory if the host supplies one. CLI 0.161.0 only
    // sends session cwd, omitting exec_command.workdir; see hook/README.md.
    const cwd = input.tool_input.cwd ?? input.tool_input.workdir ?? input.cwd ?? process.cwd()
    if (typeof cwd !== "string" || !path.isAbsolute(cwd)) throw new Error()
    return { command: input.tool_input.command, cwd }
  } catch {
    denyPreToolUse(`Cannot check ${toolName}: invalid hook input; expected tool_input.command and an absolute cwd.`)
    return null
  }
}

export function allow() {
  // Codex treats empty stdout from a successful hook as allow/continue.
}

export function denyPreToolUse(reason) {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    }),
  )
}
