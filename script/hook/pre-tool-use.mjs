#!/usr/bin/env node

import { readFileSync } from 'node:fs'
import path from 'node:path'

const SENSITIVE_PATTERNS = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env\.local$/,
  /^\.git-credentials$/,
]

const SENSITIVE_PATHS = [
  //
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
  switch (input.tool_name) {
    case 'Read':
    case 'Write':
    case 'Edit':
      return input.tool_input?.file_path
    case 'NotebookEdit':
      return input.tool_input?.notebook_path
  }
}

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'))
  const fp = extractFilePath(input)

  if (fp && isSensitiveFile(fp)) {
    console.log(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'ask',
          permissionDecisionReason: `"${path.basename(fp)}" is a sensitive file. Allow access?`,
        },
      }),
    )
    return
  }

  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'allow',
      },
    }),
  )
}

main()
