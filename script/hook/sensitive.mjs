import path from "node:path"

export const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env/,
  /^\.git-credentials$/,
]

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

  return SENSITIVE_PATTERNS.some((p) => p.test(base))
}
