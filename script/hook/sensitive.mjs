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
    SENSITIVE_PATTERNS.some((p) => p.test(base)) || SENSITIVE_PATHS.some((p) => p.test(filepath))
  )
}
