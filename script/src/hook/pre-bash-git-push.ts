#!/usr/bin/env bun

import { readFileSync } from "node:fs"
import { outputHook } from "./util"

const GIT_SENSITIVE_COMMANDS = [
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?push\b/, name: "git push" },
  { pattern: /\bgit\s+(?:-C\s+\S+\s+)?commit\b/, name: "git commit" },
]

interface IBashInput {
  tool_input?: { command?: string }
}

const input: IBashInput = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const { pattern, name } of GIT_SENSITIVE_COMMANDS) {
  if (pattern.test(command)) {
    outputHook("PreToolUse", "ask", `Intercepted "${name}". Allow?`)
    process.exit(0)
  }
}

outputHook("PreToolUse", "allow")
