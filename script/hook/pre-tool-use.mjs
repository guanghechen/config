#!/usr/bin/env node

import { readFileSync } from "node:fs"
import path from "node:path"
import { allow, denyPreToolUse, isSensitiveFile } from "../util.mjs"

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

// Codex's native built-in file mutation uses the canonical tool_name
// `apply_patch` (Write/Edit are only its matcher aliases); the Claude-style
// Read/Write/Edit/MultiEdit/NotebookEdit names are never emitted by native
// built-ins. Extension/MCP tools emit their own tool_names, but the prior `*`
// matcher only ran this Claude-style extractor, which never parsed those names
// anyway -- so narrowing to `apply_patch` drops no real coverage. Sensitive
// reads go through Bash (`cat`) and are caught by pre-bash-sensitive.mjs.
function extractFilePaths(input) {
  if (input.tool_name === "apply_patch") {
    return extractPatchPaths(input.tool_input?.command)
  }
  return []
}

const input = JSON.parse(readFileSync(0, "utf-8"))
const sensitivePath = extractFilePaths(input).find(isSensitiveFile)

if (sensitivePath) {
  denyPreToolUse(
    `"${path.basename(sensitivePath)}" is a sensitive file and is blocked by hook policy.`,
  )
} else {
  allow()
}
