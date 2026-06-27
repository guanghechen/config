#!/usr/bin/env node

/**
 * Intercept git write commands that mutate the working tree, index, or history
 * without explicit user intent. Per CLAUDE.md, all such commands require an
 * explicit user instruction.
 *
 * Plain `git commit` is intentionally NOT hook-gated: it relies on the CLAUDE.md
 * system-prompt guard (Security rule 2). Only history-rewriting
 * `git commit --amend` is intercepted here.
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
]

// `git commit --amend` rewrites history, so it stays guarded even though plain
// `git commit` does not. `--am…` covers git's unambiguous prefix abbreviation of
// `--amend`; it is only treated as an amend when the command is actually a commit.
const COMMIT = new RegExp(GIT_PREFIX + `commit\\b`)
const COMMIT_AMEND = /--am[a-z-]*/

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const { verb, pattern } of GIT_GUARDED_VERBS) {
  if (pattern.test(command)) {
    outputHook("PreToolUse", "ask", `Intercepted "git ${verb}". Allow?`)
    process.exit(0)
  }
}

if (COMMIT.test(command) && COMMIT_AMEND.test(command)) {
  outputHook("PreToolUse", "ask", `Intercepted "git commit --amend". Allow?`)
  process.exit(0)
}

outputHook("PreToolUse", "allow")
