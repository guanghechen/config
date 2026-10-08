#!/usr/bin/env node

// Guard a small set of literal, single-command file reads; see README.md.
import { allow, denyPreToolUse, readPreToolUseInput } from "../util.mjs"
import { findSensitiveShellPath } from "./bash-policy.mjs"

const input = readPreToolUseInput("Bash")
if (!input) process.exit(0)
const hit = findSensitiveShellPath(input.command, input.cwd)

if (hit) {
  denyPreToolUse(
    `Blocked ${hit.command}: sensitive path "${hit.target}" is protected by hook policy. Use a non-sensitive template or redacted fixture for this task.`,
  )
} else {
  allow()
}
