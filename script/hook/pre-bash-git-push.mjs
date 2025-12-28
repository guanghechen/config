#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const GIT_PUSH_PATTERN = /\bgit\s+push\b/

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'))
  const command = input.tool_input?.command || ''

  if (GIT_PUSH_PATTERN.test(command)) {
    console.log(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'ask',
          permissionDecisionReason: `Intercepted "git push". Allow?`,
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
