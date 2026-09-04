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
  /(?:^|[\\/])\.ssh[\\/]/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

export function isSensitiveFile(filepath) {
  const base = path.basename(filepath)
  if (SENSITIVE_PATHS.some((pattern) => pattern.test(filepath))) return true
  if (SAFE_ENV_TEMPLATE_PATTERN.test(base)) return false
  return SENSITIVE_PATTERNS.some((pattern) => pattern.test(base))
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
