#!/usr/bin/env node

/**
 * Intercept git write commands that mutate the working tree, index, or
 * history without explicit user intent. Per CLAUDE.md, all such commands
 * require an explicit user instruction.
 *
 * Limitation: shell variables / command substitution can hide the verb.
 * Defense-in-depth, not OS-level enforcement.
 */

import { readFileSync } from "node:fs"
import { outputHook } from "./util.mjs"

// Match the verb after any leading global options. Option shapes that precede
// the verb: short `-C path` / `-c k=v`, long `--opt=value`, and long `--opt value`
// with a space-separated argument (`--work-tree .`, `--namespace foo`,
// `--exec-path /tmp`). Omitting the last shape lets a space-arg global option
// hide the verb and bypass the guard.
const GIT_PREFIX = String.raw`\bgit\b(?:\s+(?:-[A-Za-z]+(?:\s+(?:"[^"]+"|'[^']+'|\S+))?|--[\w-]+(?:=\S+|\s+(?:"[^"]+"|'[^']+'|\S+))?))*\s+`

const GIT_GUARDED_VERBS = [
  { verb: "push",   pattern: new RegExp(GIT_PREFIX + `push\\b`) },
  { verb: "reset",  pattern: new RegExp(GIT_PREFIX + `reset\\b`) },
  { verb: "revert", pattern: new RegExp(GIT_PREFIX + `revert\\b`) },
  // commit covers both `git commit` and `git commit --amend`.
  { verb: "commit", pattern: new RegExp(GIT_PREFIX + `commit\\b`) },
]

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const { verb, pattern } of GIT_GUARDED_VERBS) {
  if (pattern.test(command)) {
    outputHook("PreToolUse", "ask", `Intercepted "git ${verb}". Allow?`)
    process.exit(0)
  }
}

outputHook("PreToolUse", "allow")
