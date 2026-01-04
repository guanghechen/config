#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const GIT_SENSITIVE_COMMANDS = [
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?push\b/, name: 'git push' },
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?commit\b/, name: 'git commit' },
]

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'))
  const command = input.tool_input?.command || ''

  for (const { pattern, name } of GIT_SENSITIVE_COMMANDS) {
    if (pattern.test(command)) {
      console.log(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'ask',
            permissionDecisionReason: `Intercepted "${name}". Allow?`,
          },
        }),
      )
      return
    }
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
