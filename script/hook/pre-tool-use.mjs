#!/usr/bin/env node

import { readFileSync } from "node:fs"
import path from "node:path"
import { isSensitiveFile } from "./sensitive.mjs"
import { outputHook } from "./util.mjs"

function extractFilePath(input) {
  switch (input.tool_name) {
    case "Read":
    case "Write":
    case "Edit":
    case "MultiEdit":
      return input.tool_input?.file_path
    case "NotebookEdit":
      return input.tool_input?.notebook_path
  }
}

const input = JSON.parse(readFileSync(0, "utf-8"))
const fp = extractFilePath(input)

if (fp && isSensitiveFile(fp)) {
  outputHook("PreToolUse", "deny", `"${path.basename(fp)}" is a sensitive file and is blocked by hook policy.`)
} else {
  outputHook("PreToolUse", "allow")
}
