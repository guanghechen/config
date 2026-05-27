#!/usr/bin/env node

import { readFileSync } from "node:fs"

const input = JSON.parse(readFileSync(0, "utf-8"))
const event = input.hook_event_name || "Codex"

const title = input.title || `Codex: ${event}`
const message =
  input.message ||
  input.last_assistant_message ||
  (event === "Stop" ? "任务执行完毕" : "有新通知")

const body = message.length > 200 ? message.slice(0, 197) + "..." : message

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
  process.stderr.write(`\x1b]9;${title}: ${body}\x07`)
} else {
  process.stderr.write("\x07")
}
