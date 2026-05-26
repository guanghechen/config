#!/usr/bin/env node

/**
 * Strategy B Bash guardrail: deny when a "read / search / load / network /
 * archive / editor" command names a sensitive file in its arguments.
 *
 * Limitations: pattern matching cannot follow shell variables, command
 * substitution, xargs piping, or self-written scripts (`node -e ...`).
 * This hook blocks the obvious paths only — defense-in-depth is the goal.
 */

import { readFileSync } from "node:fs"
import { SENSITIVE_PATHS, SENSITIVE_PATTERNS } from "./sensitive.mjs"
import { outputHook } from "./util.mjs"

const DANGEROUS_COMMANDS = new Set([
  // read content
  "cat", "bat", "less", "more", "head", "tail", "tac", "nl", "od", "xxd", "hexdump", "strings",
  // search / transform (output content)
  "rg", "grep", "egrep", "fgrep", "ag", "ack", "sed", "awk", "cut", "tr",
  // load / execute (exfiltrates env into shell)
  "source", ".",
  // network outbound
  "curl", "wget", "nc", "ncat", "socat", "scp", "rsync", "sftp", "ftp",
  // archive (can wrap a sensitive file for transport)
  "tar", "zip", "gzip", "bzip2", "xz", "7z", "gpg", "openssl",
  // editors (rare under non-interactive Bash but cheap to cover)
  "vim", "nvim", "vi", "nano", "emacs", "view",
])

const PROCESS_WRAPPERS = new Set(["timeout", "time", "nice", "nohup", "stdbuf", "xargs", "sudo", "env"])

const SHELL_DASH_C = new Set(["bash", "sh", "zsh", "fish", "dash", "ash", "ksh"])

const SUBCOMMAND_SEPARATORS = /(?:&&|\|\||;|\||\|&|&|\n)/

function looksSensitive(token) {
  let cleaned = token.replace(/^['"]|['"]$/g, "")
  cleaned = cleaned.replace(/^@/, "") // curl --data @file
  if (!cleaned || cleaned.startsWith("-")) return false
  if (SENSITIVE_PATHS.some((p) => p.test(cleaned))) return true
  const base = cleaned.includes("/") ? cleaned.slice(cleaned.lastIndexOf("/") + 1) : cleaned
  if (SENSITIVE_PATTERNS.some((p) => p.test(base))) return true
  return false
}

function tokenize(subcommand) {
  // Light tokenizer: split on whitespace while preserving simple quoted spans.
  const tokens = []
  const re = /"([^"]*)"|'([^']*)'|(\S+)/g
  let m
  while ((m = re.exec(subcommand)) !== null) {
    tokens.push(m[1] ?? m[2] ?? m[3])
  }
  return tokens
}

function isEnvAssignment(tok) {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(tok)
}

function isWrapperArg(tok) {
  if (tok.startsWith("-")) return true                // -n, --null-stdin
  if (/^\d+(?:[smhd]|ms)?$/.test(tok)) return true    // 5, 30s, 1m
  if (isEnvAssignment(tok)) return true               // env FOO=bar
  return false
}

function findOffendingCommand(subcommand) {
  const tokens = tokenize(subcommand)
  if (tokens.length === 0) return null

  let i = 0
  // Skip leading `FOO=bar` assignments and process wrappers like `timeout 5`.
  while (i < tokens.length) {
    if (isEnvAssignment(tokens[i])) { i++; continue }
    if (PROCESS_WRAPPERS.has(tokens[i])) {
      i++
      while (i < tokens.length && isWrapperArg(tokens[i])) i++
      continue
    }
    break
  }
  const cmd = tokens[i]
  if (!cmd) return null

  const base = cmd.includes("/") ? cmd.slice(cmd.lastIndexOf("/") + 1) : cmd

  // `bash -c "real command"`: recurse into the quoted script.
  if (SHELL_DASH_C.has(base)) {
    const dashC = tokens.indexOf("-c", i + 1)
    if (dashC !== -1 && tokens[dashC + 1]) {
      const inner = tokens[dashC + 1]
      for (const sub of inner.split(SUBCOMMAND_SEPARATORS)) {
        const hit = findOffendingCommand(sub.trim())
        if (hit) return hit
      }
    }
    return null
  }

  if (!DANGEROUS_COMMANDS.has(base)) return null

  for (const tok of tokens.slice(i + 1)) {
    if (looksSensitive(tok)) return { cmd: base, target: tok }
  }
  return null
}

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const sub of command.split(SUBCOMMAND_SEPARATORS)) {
  const hit = findOffendingCommand(sub.trim())
  if (hit) {
    outputHook(
      "PreToolUse",
      "deny",
      `Blocked: "${hit.cmd}" targeting sensitive path "${hit.target}". Edit the file directly or ask the user to handle it.`,
    )
    process.exit(0)
  }
}

outputHook("PreToolUse", "allow")
