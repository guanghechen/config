#!/usr/bin/env bun

import { readFileSync } from "node:fs"
import path from "node:path"
import { outputHook } from "./util"

const SENSITIVE_PATTERNS: RegExp[] = [
  /\.http_request$/,
  /\.http_response$/,
  /^\.env\.local$/,
  /^\.git-credentials$/,
]

const SENSITIVE_PATHS: RegExp[] = [
  /(?:^|[\\/])\.ssh[\\/]/,
  /(?:^|[\\/])local[\\/]config\.(?:fish|ps1)$/,
  /(?:^|[\\/])local[\\/]env\.[^/\\]+$/,
]

function isSensitiveFile(filepath: string): boolean {
  const base = path.basename(filepath)
  return (
    SENSITIVE_PATTERNS.some((p) => p.test(base)) || SENSITIVE_PATHS.some((p) => p.test(filepath))
  )
}

interface IToolInput {
  tool_name: string
  tool_input?: { file_path?: string; notebook_path?: string }
}

function extractFilePath(input: IToolInput): string | undefined {
  switch (input.tool_name) {
    case "Read":
    case "Write":
    case "Edit":
      return input.tool_input?.file_path
    case "NotebookEdit":
      return input.tool_input?.notebook_path
  }
}

const input: IToolInput = JSON.parse(readFileSync(0, "utf-8"))
const fp = extractFilePath(input)

if (fp && isSensitiveFile(fp)) {
  outputHook("PreToolUse", "ask", `"${path.basename(fp)}" is a sensitive file. Allow access?`)
} else {
  outputHook("PreToolUse", "allow")
}
