#!/usr/bin/env node

import { readFileSync } from "node:fs"

const input = JSON.parse(readFileSync(0, "utf-8"))
const event = input.hook_event_name || "Claude Code"

const title = input.title || `Claude Code: ${event}`
const message =
  input.message ||
  input.last_assistant_message ||
  (event === "Stop" ? "任务执行完毕" : "有新通知")

// Truncate to avoid overly long notification text.
const body = message.length > 200 ? message.slice(0, 197) + "..." : message

// Detect OSC 9 capable terminals (skip WSL/Windows Terminal where it's unreliable).
const wt = !!process.env.WT_SESSION
const term = process.env.TERM_PROGRAM || ""
const termVar = process.env.TERM || ""
const iterm = !!process.env.ITERM_SESSION_ID

const supportsOsc9 =
  !wt &&
  (term === "WezTerm" ||
    term === "ghostty" ||
    iterm ||
    /^(xterm-kitty|wezterm)/.test(termVar))

if (supportsOsc9) {
  // OSC 9: terminal desktop notification with message text.
  process.stderr.write(`\x1b]9;${title}: ${body}\x07`)
} else {
  // BEL: universal fallback — works in Windows Terminal, most Linux terminals, macOS Terminal.
  process.stderr.write("\x07")
}
