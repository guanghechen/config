#!/usr/bin/env node

/**
 * Gemini CLI BeforeTool hook for sensitive file protection.
 * Prompts user confirmation before accessing sensitive files.
 */

import { readFileSync } from 'node:fs'
import path from 'node:path'

const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env\.local$/,
  /^\.git-credentials$/,
]

const SENSITIVE_PATHS = [
  /(?:^|[\\/])\.ssh[\\/]/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

function isSensitiveFile(filepath) {
  const base = path.basename(filepath)
  if (SENSITIVE_PATTERNS.some(p => p.test(base))) return true
  if (SENSITIVE_PATHS.some(p => p.test(filepath))) return true
  return false
}

function extractFilePath(input) {
  const toolName = input.tool_name?.toLowerCase() || ''
  const toolInput = input.tool_input || {}

  // Gemini CLI tool names may differ from Claude Code
  if (toolName.includes('read') || toolName.includes('write') || toolName.includes('edit')) {
    return toolInput.file_path || toolInput.path || toolInput.filePath
  }
  if (toolName.includes('notebook')) {
    return toolInput.notebook_path || toolInput.notebookPath
  }

  // Fallback: check common path fields
  return toolInput.file_path || toolInput.path || toolInput.filePath
}

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'))
  const fp = extractFilePath(input)

  if (fp && isSensitiveFile(fp)) {
    console.log(
      JSON.stringify({
        decision: 'ask',
        reason: `"${path.basename(fp)}" is a sensitive file. Allow access?`,
      }),
    )
    return
  }

  console.log(
    JSON.stringify({
      decision: 'allow',
    }),
  )
}

main()
