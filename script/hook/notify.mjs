#!/usr/bin/env node

import { readFileSync } from "node:fs"

const NOTIFICATION_METHOD = "auto"

const input = JSON.parse(readFileSync(0, "utf-8"))
const event = input.hook_event_name || "Claude Code"

const title = sanitize(input.title || `Claude Code: ${event}`)
const message = truncate(
  sanitize(
    input.message ||
      input.last_assistant_message ||
      (event === "Stop" ? "任务执行完毕" : "有新通知"),
  ),
)
const shouldUseBel =
  NOTIFICATION_METHOD === "bel" ||
  (NOTIFICATION_METHOD === "auto" && !supportsOsc9())

if (shouldUseBel) {
  writeBel()
} else {
  writeOsc9(`${title}: ${message}`)
}

function supportsOsc9() {
  const termProgram = (process.env.TERM_PROGRAM || "").toLowerCase()
  const term = (process.env.TERM || "").toLowerCase()

  return (
    termProgram === "ghostty" ||
    termProgram === "wezterm" ||
    !!process.env.ITERM_SESSION_ID ||
    /^(xterm-ghostty|xterm-kitty|wezterm)/.test(term)
  )
}

function writeOsc9(text) {
  const payload = text.replaceAll("\x1b", "\x1b\x1b")

  if (process.env.TMUX || process.env.TMUX_PANE) {
    process.stderr.write(`\x1bPtmux;\x1b\x1b]9;${payload}\x07\x1b\\`)
    return
  }

  process.stderr.write(`\x1b]9;${payload}\x07`)
}

function writeBel() {
  process.stderr.write("\x07")
}

function truncate(text) {
  return text.length > 200 ? `${text.slice(0, 197)}...` : text
}

function sanitize(text) {
  return String(text)
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, " ")
    .replace(/[\x07\x1b]/g, "")
    .replace(/\s+/g, " ")
    .trim()
}
