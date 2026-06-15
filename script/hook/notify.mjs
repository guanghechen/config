#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs"
import { execFileSync } from "node:child_process"

const BODY_MAX = 200
const BEL = "\x07"

main()

function main() {
  notify(buildBody(readInput()))
}

// ---- input -> notification body ----

function readInput() {
  try {
    return JSON.parse(readFileSync(0, "utf-8"))
  } catch {
    return {}
  }
}

function buildBody(input) {
  const fallback = input.hook_event_name === "Stop" ? "任务执行完毕" : "有新通知"
  const message = input.message || input.last_assistant_message || fallback
  return truncate(sanitize(`Claude Code: ${message}`))
}

// Strip control chars (incl. ESC \x1b and BEL \x07): message comes from the
// model-controlled last_assistant_message; stripping them prevents injecting extra
// OSC sequences or prematurely terminating the OSC 9 payload.
function sanitize(text) {
  return String(text)
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
}

// Truncate by code point to avoid splitting a surrogate pair (emoji)
function truncate(text) {
  const chars = [...text]
  return chars.length > BODY_MAX
    ? `${chars.slice(0, BODY_MAX - 3).join("")}...`
    : text
}

// ---- notification delivery ----

// Two complementary signals:
//  1) BEL -> our own pane's pty, sets the window bell flag on its session (visible
//     when you switch back to that session).
//  2) OSC 9 -> the tty of every attached client, straight to the outer terminal.
//     Writing the client tty directly bypasses pane->tmux forwarding: no buffering,
//     unaffected by whether Claude's window is currently visible. Whether it pops is
//     left to the terminal's own focus handling (Ghostty suppresses when focused =
//     no interruption while you're here, pops when unfocused = notify only after you leave).
//
// Key: inside tmux, never fall back to /dev/tty -- the hook subprocess's /dev/tty is the
// pane pty, and OSC 9 through it gets buffered by tmux per window visibility, causing a
// "delayed pop only after switching back to that window". With no attached client nobody
// is watching, so just give up.
function notify(body) {
  const paneTty = tmuxPaneTty()
  if (paneTty) tryWrite(paneTty, BEL)

  if (process.env.TMUX) {
    for (const tty of tmuxClientTtys()) tryWrite(tty, osc9(body))
    return
  }

  // Non-tmux: /dev/tty is the outer terminal, delivered directly with no buffering
  tryWrite("/dev/tty", BEL + osc9(body))
}

function osc9(text) {
  return `\x1b]9;${text}${BEL}`
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
    return true
  } catch {
    return false
  }
}

// ---- tmux queries ----

// The hook subprocess's /dev/tty isn't necessarily this pane's pty, so resolve it
// explicitly via the pane id
function tmuxPaneTty() {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return null
  return tmuxQuery(["display", "-p", "-t", pane, "#{pane_tty}"])
}

// Enumerate the tty of every attached client on this tmux server. Regardless of which
// session Claude runs in or where the user switch-clients to, the client tty always
// points at the user's current outer terminal.
function tmuxClientTtys() {
  if (!process.env.TMUX) return []
  const out = tmuxQuery(["list-clients", "-F", "#{client_tty}"])
  if (!out) return []
  return out
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean)
}

// timeout guards against the hook subprocess blocking forever if the tmux server hangs
function tmuxQuery(args) {
  try {
    const out = execFileSync("tmux", args, {
      encoding: "utf-8",
      timeout: 1000,
    }).trim()
    return out || null
  } catch {
    return null
  }
}
