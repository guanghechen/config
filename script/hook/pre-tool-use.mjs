#!/usr/bin/env node

import { readFileSync } from "node:fs"
import path from "node:path"
import { isSensitiveFile } from "./sensitive.mjs"
import { allow, denyPreToolUse } from "./util.mjs"

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

function extractFilePaths(input) {
  switch (input.tool_name) {
    case "Read":
    case "Write":
    case "Edit":
    case "MultiEdit":
      return [input.tool_input?.file_path].filter(Boolean)
    case "NotebookEdit":
      return [input.tool_input?.notebook_path].filter(Boolean)
    case "apply_patch":
      return extractPatchPaths(input.tool_input?.command)
    default:
      return []
  }
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
