#!/usr/bin/env node

import { writeFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import { terminalTty } from "./tty.mjs"

const BEL = "\x07"

main()

// Emit a bare BEL and let the chain decide whether to surface a desktop notification.
// Inside tmux the BEL lands on this pane's pty; tmux's monitor-bell captures it and
// forwards it to the outer terminal, whose own focus handling decides whether to pop
// (e.g. Ghostty with bell-features=system notifies only while unfocused). Outside tmux it
// lands on the terminal Claude runs in. We make no focus decision and carry no payload
// here -- that authority belongs to the terminal.
function main() {
  const tty = tmuxPaneTty() ?? terminalTty()
  if (tty) tryWrite(tty, BEL)
}

// Inside tmux, resolve the pane's pty from the pane id -- that's the tty tmux's
// monitor-bell watches.
function tmuxPaneTty() {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return null
  return tmuxQuery(["display", "-p", "-t", pane, "#{pane_tty}"])
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
  } catch {}
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
