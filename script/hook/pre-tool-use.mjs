#!/usr/bin/env node

import { allow, denyPreToolUse, isSensitiveFile, readPreToolUseInput } from "../util.mjs"

function extractPatchPaths(patchText) {
  if (typeof patchText !== "string") return []

  const paths = []
  const re = /^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm
  let match
  while ((match = re.exec(patchText)) !== null) {
    paths.push(match[1].trim())
  }

  const moveRe = /^\*\*\* Move to: (.+)$/gm
  while ((match = moveRe.exec(patchText)) !== null) {
    paths.push(match[1].trim())
  }

  return paths
}

// apply_patch is Codex's canonical patch tool; Edit and Write are matcher
// aliases. MCP and other tools need their own argument handling. This hook
// protects patch paths only, not every possible file read or mutation.
const input = readPreToolUseInput("apply_patch")
if (!input) process.exit(0)
const sensitivePath = extractPatchPaths(input.command)
  .find((filepath) => isSensitiveFile(filepath, input.cwd))

if (sensitivePath) {
  denyPreToolUse(
    `Sensitive path "${sensitivePath}" is protected by hook policy. Use a non-sensitive template or redacted fixture for this task.`,
  )
} else {
  allow()
}
