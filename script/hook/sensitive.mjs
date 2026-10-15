import path from "node:path"

export const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env/,
  /^\.git-credentials$/,
  /^\.credentials\.json$/,
]

// Env templates carry placeholders only, so they stay readable outside protected directories.
const READABLE_TEMPLATES = new Set([".env.example"])

export const SENSITIVE_PATHS = [
  /(?:^|[\\/])\.ssh(?:[\\/]|$)/,
  /(?:^|[\\/])\.credentials(?:[\\/]|$)/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

export function isSensitiveFile(filepath) {
  const normalized = filepath.replaceAll("\\", "/")
  const base = path.posix.basename(normalized)
  if (SENSITIVE_PATHS.some((p) => p.test(normalized))) return true

  // Keep descendants of protected directories blocked as well.
  const parents = normalized.split("/").slice(0, -1)
  if (parents.some((part) => SENSITIVE_PATTERNS.some((p) => p.test(part)))) return true

  if (READABLE_TEMPLATES.has(base)) return false
  return SENSITIVE_PATTERNS.some((p) => p.test(base))
}
