#!/usr/bin/env node

/**
 * Gemini CLI BeforeTool hook for git command interception.
 * Prompts user confirmation before git push/commit operations.
 */

import { readFileSync } from 'node:fs'

const GIT_SENSITIVE_COMMANDS = [
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?push\b/, name: 'git push' },
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?commit\b/, name: 'git commit' },
]

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'))

  // Gemini CLI shell tool input may vary
  const toolInput = input.tool_input || {}
  const command = toolInput.command || toolInput.cmd || toolInput.script || ''

  for (const { pattern, name } of GIT_SENSITIVE_COMMANDS) {
    if (pattern.test(command)) {
      console.log(
        JSON.stringify({
          decision: 'ask',
          reason: `Intercepted "${name}". Allow?`,
        }),
      )
      return
    }
  }

  console.log(
    JSON.stringify({
      decision: 'allow',
    }),
  )
}

main()
