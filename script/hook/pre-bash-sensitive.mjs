#!/usr/bin/env node

/**
 * Bash guardrail: deny when a read/search/load/network/archive/editor command
 * names a sensitive file in its arguments.
 *
 * Limitations: pattern matching cannot follow shell variables, command
 * substitution, xargs piping, or self-written scripts (`node -e ...`). This hook
 * blocks obvious paths only; it is defense-in-depth, not OS-level enforcement.
 */

import { readFileSync } from "node:fs"
import { allow, denyPreToolUse, isSensitiveFile } from "../util.mjs"

const DANGEROUS_COMMANDS = new Set([
  "cat", "bat", "less", "more", "head", "tail", "tac", "nl", "od", "xxd", "hexdump", "strings",
  "rg", "grep", "egrep", "fgrep", "ag", "ack", "sed", "awk", "cut", "tr",
  "source", ".",
  "curl", "wget", "nc", "ncat", "socat", "scp", "rsync", "sftp", "ftp",
  "tar", "zip", "gzip", "bzip2", "xz", "7z", "gpg", "openssl",
  "vim", "nvim", "vi", "nano", "emacs", "view",
])

const PROCESS_WRAPPERS = new Set(["timeout", "time", "nice", "nohup", "stdbuf", "xargs", "sudo", "env"])
const SHELL_DASH_C = new Set(["bash", "sh", "zsh", "fish", "dash", "ash", "ksh"])
const SUBCOMMAND_SEPARATORS = /(?:&&|\|\||;|\||\|&|&|\n)/

function looksSensitive(token) {
  let cleaned = token.replace(/^[']|[']$/g, "").replace(/^[\"]|[\"]$/g, "")
  cleaned = cleaned.replace(/^@/, "")
  if (!cleaned || cleaned.startsWith("-")) return false
  return isSensitiveFile(cleaned)
}

function tokenize(subcommand) {
  const tokens = []
  const re = /"([^"]*)"|'([^']*)'|(\S+)/g
  let match
  while ((match = re.exec(subcommand)) !== null) {
    tokens.push(match[1] ?? match[2] ?? match[3])
  }
  return tokens
}

function isEnvAssignment(token) {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(token)
}

function isWrapperArg(token) {
  if (token.startsWith("-")) return true
  if (/^\d+(?:[smhd]|ms)?$/.test(token)) return true
  return isEnvAssignment(token)
}

function findOffendingCommand(subcommand) {
  const tokens = tokenize(subcommand)
  if (tokens.length === 0) return null

  let i = 0
  while (i < tokens.length) {
    if (isEnvAssignment(tokens[i])) {
      i++
      continue
    }
    if (PROCESS_WRAPPERS.has(tokens[i])) {
      i++
      while (i < tokens.length && isWrapperArg(tokens[i])) i++
      continue
    }
    break
  }

  const command = tokens[i]
  if (!command) return null

  const base = command.includes("/") ? command.slice(command.lastIndexOf("/") + 1) : command

  if (SHELL_DASH_C.has(base)) {
    const dashC = tokens.indexOf("-c", i + 1)
    if (dashC !== -1 && tokens[dashC + 1]) {
      for (const sub of tokens[dashC + 1].split(SUBCOMMAND_SEPARATORS)) {
        const hit = findOffendingCommand(sub.trim())
        if (hit) return hit
      }
    }
    return null
  }

  if (!DANGEROUS_COMMANDS.has(base)) return null

  for (const token of tokens.slice(i + 1)) {
    if (looksSensitive(token)) return { command: base, target: token }
  }
  return null
}

const input = JSON.parse(readFileSync(0, "utf-8"))
const command = input.tool_input?.command || ""

for (const sub of command.split(SUBCOMMAND_SEPARATORS)) {
  const hit = findOffendingCommand(sub.trim())
  if (hit) {
    denyPreToolUse(
      `Blocked: "${hit.command}" targeting sensitive path "${hit.target}". Edit the file directly or ask the user to handle it.`,
    )
    process.exit(0)
  }
}

allow()
