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
import { isSensitiveFile } from "./sensitive.mjs"
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

const PROCESS_WRAPPERS = new Set([
  "timeout", "time", "nice", "nohup", "stdbuf", "xargs", "sudo", "env", "exec", "command", "builtin",
])

const SHELL_DASH_C = new Set(["bash", "sh", "zsh", "fish", "dash", "ash", "ksh"])

// Commands that join their arguments into a script and run it.
const SCRIPT_RUNNERS = new Set(["eval", "watch"])

const SEARCH_COMMANDS = new Set(["rg", "grep", "egrep", "fgrep"])
const SEARCH_VALUE_OPTIONS = new Set([
  "-A", "--after-context", "-B", "--before-context", "-C", "--context",
  "-m", "--max-count", "--max-depth", "--max-filesize", "-M", "--max-columns",
  "-g", "--glob", "--iglob", "-t", "--type", "-T", "--type-not", "--type-add", "--type-clear",
  "-E", "--encoding", "--engine", "--dfa-size-limit", "--regex-size-limit", "-j", "--threads",
  "--replace", "--sort", "--sortr", "--color", "--colors", "--path-separator",
  "--field-context-separator", "--field-match-separator", "--context-separator",
  "--hostname-bin", "--hyperlink-format", "--pre", "--pre-glob",
  "--include", "--exclude", "--exclude-dir", "--label", "--binary-files",
  "-d", "--directories", "-D", "--devices",
])

function looksSensitive(token) {
  let cleaned = token.replace(/^['"]|['"]$/g, "")
  cleaned = cleaned.replace(/^@/, "") // curl --data @file
  if (!cleaned || cleaned.startsWith("-")) return false
  return isSensitiveFile(cleaned)
}

function searchFileArguments(command, args) {
  const files = []
  const positional = []
  let explicitPattern = false
  let options = true

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (options && arg === "--") {
      options = false
      continue
    }
    if (options && arg.startsWith("--")) {
      const equals = arg.indexOf("=")
      const option = equals === -1 ? arg : arg.slice(0, equals)
      if (option === "--files") explicitPattern = true
      if (option === "--regexp" || option === "--file" || option === "--exclude-from") {
        const value = equals === -1 ? args[++i] : arg.slice(equals + 1)
        if (option !== "--exclude-from") explicitPattern = true
        if (option !== "--regexp" && value) files.push(value)
      } else if (SEARCH_VALUE_OPTIONS.has(option) && equals === -1) {
        i++
      }
      continue
    }
    if (options && arg.startsWith("-") && arg !== "-") {
      for (let j = 1; j < arg.length; j++) {
        const option = "-" + arg[j]
        if (option === "-e" || option === "-f") {
          const value = arg.slice(j + 1) || args[++i]
          explicitPattern = true
          if (option === "-f" && value) files.push(value)
          break
        }
        // grep -E/-r are flags; rg -E/-r consume an encoding/replacement.
        const takesValue = SEARCH_VALUE_OPTIONS.has(option) && (option !== "-E" || command === "rg")
        if (takesValue || (option === "-r" && command === "rg")) {
          if (j === arg.length - 1) i++
          break
        }
      }
      continue
    }
    positional.push(arg)
  }

  // An explicit pattern can follow file operands, so decide after parsing all options.
  return files.concat(explicitPattern ? positional : positional.slice(1))
}

// Splits a script into simple commands of words the way the shell reads them: quotes and
// backslashes keep `|`, `;`, `&` and whitespace inside a word, so quoted patterns and
// programs such as `rg "a|b"` or `awk '{x; y}'` stay whole.
function splitCommands(script) {
  const commands = []
  let words = []
  let word = null
  const endWord = () => {
    if (word !== null) words.push(word)
    word = null
  }
  const endCommand = () => {
    endWord()
    if (words.length > 0) commands.push(words)
    words = []
  }
  for (let i = 0; i < script.length; i++) {
    const ch = script[i]
    if (ch === "'") {
      const end = script.indexOf("'", i + 1)
      const stop = end === -1 ? script.length : end
      word = (word ?? "") + script.slice(i + 1, stop)
      i = stop
    } else if (ch === '"') {
      word ??= ""
      for (i++; i < script.length && script[i] !== '"'; i++) {
        if (script[i] === "\\" && '$`"\\\n'.includes(script[i + 1] ?? "")) i++
        word += script[i]
      }
    } else if (ch === "\\") {
      i++
      if (i < script.length && script[i] !== "\n") word = (word ?? "") + script[i]
    } else if (ch === "\n" || ch === ";" || ch === "&" || ch === "|") {
      endCommand()
    } else if (/\s/.test(ch)) {
      endWord()
    } else {
      word = (word ?? "") + ch
    }
  }
  endCommand()
  return commands
}

// Returns the script a shell runs with -c, or null when it runs a file or stays interactive.
// The c may sit in a cluster such as -lc or -ec, and options may follow it, as in
// `bash -c -l "..."`, so the script is the first operand after all options.
function shellScript(args) {
  let command = false
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === "--") return command ? (args[i + 1] ?? null) : null
    if (arg.startsWith("--")) continue
    if (/^[-+][A-Za-z]+$/.test(arg)) {
      if (arg[0] === "-" && arg.includes("c")) command = true
      if (/[oO]/.test(arg)) i++ // -o / -O take an option name
      continue
    }
    return command ? arg : null
  }
  return null
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

function findOffendingCommand(tokens) {
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

  // `bash -lc "real command"`: recurse into the script the shell runs.
  if (SHELL_DASH_C.has(base)) {
    const script = shellScript(tokens.slice(i + 1))
    return script === null ? null : findOffendingInScript(script)
  }

  if (SCRIPT_RUNNERS.has(base)) {
    let j = i + 1
    while (j < tokens.length && isWrapperArg(tokens[j])) j++ // watch -n 2
    return findOffendingInScript(tokens.slice(j).join(" "))
  }

  if (!DANGEROUS_COMMANDS.has(base)) return null

  const args = tokens.slice(i + 1)
  const files = SEARCH_COMMANDS.has(base) ? searchFileArguments(base, args) : args
  for (const tok of files) {
    if (looksSensitive(tok)) return { cmd: base, target: tok }
  }
  return null
}

function findOffendingInScript(script) {
  for (const tokens of splitCommands(script)) {
    const hit = findOffendingCommand(tokens)
    if (hit) return hit
  }
  return null
}

const input = JSON.parse(readFileSync(0, "utf-8"))
const hit = findOffendingInScript(input.tool_input?.command || "")
if (hit) {
  outputHook(
    "PreToolUse",
    "deny",
    `Blocked: "${hit.cmd}" targeting sensitive path "${hit.target}". Ask the user to handle this file.`,
  )
}
