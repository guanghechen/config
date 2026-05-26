#!/usr/bin/env node

import { readFileSync } from "node:fs"
import { outputHook } from "./util.mjs"

const GIT_CONFIRM_COMMANDS = [
  { pattern: /\bgit\s+(?:-C\s+(?:"[^"]+"|'[^']+'|\S+)\s+)?push\b/, name: "git push" },
  { pattern: /\bgit\s+(?:-C\s+(?:"[^"]+"|'[^']+'|\S+)\s+)?reset\b/, name: "git reset" },
  {
    pattern: /\bgit\s+(?:-C\s+(?:"[^"]+"|'[^']+'|\S+)\s+)?commit\b[^;&|\n]*\s--amend\b/,
    name: "git commit --amend",
  },
]

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const { pattern, name } of GIT_CONFIRM_COMMANDS) {
  if (pattern.test(command)) {
    outputHook("PreToolUse", "ask", `Intercepted "${name}". Allow?`)
    process.exit(0)
  }
}

outputHook("PreToolUse", "allow")
