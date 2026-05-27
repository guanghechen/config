#!/usr/bin/env node

/**
 * Intercept git write commands that mutate the working tree, index, or history.
 * Codex PreToolUse hooks do not support Claude-style `ask`, so this hook blocks
 * instead of prompting.
 */

import { readFileSync } from "node:fs"
import { allow, denyPreToolUse } from "./util.mjs"

const GIT_PREFIX = String.raw`\bgit\b(?:\s+(?:-[A-Za-z]+(?:\s+(?:"[^"]+"|'[^']+'|\S+))?|--[\w-]+(?:=\S+)?))*\s+`

const GIT_GUARDED_VERBS = [
  { verb: "push", pattern: new RegExp(GIT_PREFIX + `push\\b`) },
  { verb: "reset", pattern: new RegExp(GIT_PREFIX + `reset\\b`) },
  { verb: "revert", pattern: new RegExp(GIT_PREFIX + `revert\\b`) },
  { verb: "commit", pattern: new RegExp(GIT_PREFIX + `commit\\b`) },
]

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const { verb, pattern } of GIT_GUARDED_VERBS) {
  if (pattern.test(command)) {
    denyPreToolUse(
      `Blocked: "git ${verb}" mutates repository state. Codex hooks cannot ask for confirmation here; run it yourself or temporarily disable this hook if intentional.`,
    )
    process.exit(0)
  }
}

allow()
