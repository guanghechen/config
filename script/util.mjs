import path from "node:path"

export const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env/,
  /^\.git-credentials$/,
]

export const SENSITIVE_PATHS = [
  /(?:^|[\\/])\.ssh[\\/]/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

export function isSensitiveFile(filepath) {
  const base = path.basename(filepath)
  return (
    SENSITIVE_PATTERNS.some((pattern) => pattern.test(base))
    || SENSITIVE_PATHS.some((pattern) => pattern.test(filepath))
  )
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
