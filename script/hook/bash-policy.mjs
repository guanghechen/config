import { realpathSync } from "node:fs"
import { homedir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { isSensitiveFile } from "../util.mjs"
import { shellWords } from "./shell-words.mjs"

// Deliberately small command vocabulary. Unknown options skip argument checks.
const COUNT_OPTIONS = { "-n": "text", "--lines": "text", "-c": "text", "--bytes": "text" }
const VALUE_OPTIONS = {
  cat: {}, head: COUNT_OPTIONS, tail: COUNT_OPTIONS,
  curl: { "-T": "file", "--upload-file": "file", "-d": "data", "--data": "data", "--data-binary": "data" },
}
const FLAGS = {
  cat: /^(?:-[AbeEnstTuv]+|--(?:number|number-nonblank|squeeze-blank|show-all|show-ends|show-tabs|show-nonprinting))$/,
  head: /^(?:-[qvz]+|--(?:quiet|silent|verbose|zero-terminated))$/,
  tail: /^(?:-[qvzFf]+|--(?:quiet|silent|verbose|zero-terminated|retry|follow(?:=(?:name|descriptor))?))$/,
  curl: /^(?:-[fsSLkqv]+|--(?:fail|silent|show-error|location|insecure|disable|verbose))$/,
}
const INPUT_REDIRECTS = new Set(["<", "<>", "<&"])

function filePath(token) {
  return token.expandHome ? homedir() + token.value.slice(1) : token.value
}

function localFileUrl(value) {
  if (!/^file:\/\//i.test(value)) return null
  try {
    const url = new URL(value)
    // curl accepts this authority for local files; Node rejects it on Unix.
    if (url.hostname === "127.0.0.1") url.hostname = ""
    return fileURLToPath(url)
  } catch { return null }
}

function inputPaths(command, args) {
  if (!Object.hasOwn(VALUE_OPTIONS, command)) return []
  const paths = []
  let options = true
  for (let i = 0; i < args.length; i++) {
    const token = args[i]
    const value = token.value
    if (options && value === "--") { options = false; continue }
    if (options && value !== "-" && value.startsWith("-")) {
      if (FLAGS[command].test(value)) continue
      const match = value.match(/^(--[^=]+)(?:=(.*))?$/s) ?? value.match(/^(-[A-Za-z])(.+)?$/s)
      const kind = match && VALUE_OPTIONS[command][match[1]]
      if (!kind) return []
      const argument = match[2] === undefined ? args[++i] : { value: match[2] }
      if (!argument) return []
      if (kind === "file") paths.push(filePath(argument))
      if (kind === "data" && argument.value.startsWith("@")) paths.push(argument.value.slice(1))
    } else if (command === "curl") {
      const filepath = localFileUrl(value)
      if (filepath !== null) paths.push(filepath)
    } else {
      paths.push(filePath(token))
    }
  }
  return paths
}

export function findSensitiveShellPath(command, cwd) {
  const tokens = shellWords(command)
  if (!tokens) return null
  // A single command uses the host's physical cwd; shell state is never simulated.
  try { cwd = realpathSync.native(cwd) } catch {}
  const words = []
  const inputs = []
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]
    if (token.type === "word") { words.push(token); continue }
    const target = tokens[++i]
    if (target?.type !== "word") return null
    if (!INPUT_REDIRECTS.has(token.value)) continue
    if (token.value === "<&" && /^(?:\d+-?|-)$/.test(target.value)) continue
    inputs.push(filePath(target))
  }
  const sensitive = (filepath) => filepath && filepath !== "-" && isSensitiveFile(filepath, cwd)
  const redirected = inputs.find(sensitive)
  if (redirected) return { command: "redirection", target: redirected }
  const base = path.posix.basename(words[0]?.value ?? "")
  const target = inputPaths(base, words.slice(1)).find(sensitive)
  return target ? { command: base, target } : null
}
