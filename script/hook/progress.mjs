#!/usr/bin/env node

import { execFileSync } from "node:child_process"
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// Claude Code keeps a static terminal title under multiplexers, so a busy pane looks
// idle. Report activity as an OSC 9;4 progress state instead; tmux captures it as
// pane_pb_state. Background subagents outlive the turn, so busy means an open turn or
// any live subagent, tracked as one marker file each under a per-session directory.
const BUSY = "\x1b]9;4;3\x07"
const IDLE = "\x1b]9;4;0\x07"

main()

function main() {
  const event = readEvent()
  if (!event?.session_id) return
  const dir = join(tmpdir(), "claude-progress", event.session_id)
  const name = event.hook_event_name
  const marker = join(dir, name.startsWith("Subagent") ? `agent-${event.agent_id}` : "turn")

  switch (name) {
    case "UserPromptSubmit":
    case "SubagentStart":
      mkdirSync(dir, { recursive: true })
      writeFileSync(marker, "")
      break
    // Stop is skipped on user interrupt; idle_prompt is the fallback that closes the turn.
    case "Stop":
    case "StopFailure":
    case "Notification":
    case "SubagentStop":
      rmSync(marker, { force: true })
      break
    // A starting process has no open turn or subagent; resetting also clears a busy
    // state stranded on the pane by a session that died without SessionEnd.
    case "SessionStart":
    case "SessionEnd":
      rmSync(dir, { recursive: true, force: true })
      break
    default:
      return
  }

  const tty = terminalTty()
  if (tty) tryWrite(tty, isBusy(dir) ? BUSY : IDLE)
}

function readEvent() {
  try {
    return JSON.parse(readFileSync(0, "utf-8"))
  } catch {
    return null
  }
}

function isBusy(dir) {
  try {
    return readdirSync(dir).length > 0
  } catch {
    return false
  }
}

// Hook subprocesses have no controlling terminal. Claude Code runs them through a shell,
// so its tty is at most two parents up. Stop there: walking further would reach an outer
// session's terminal when this Claude is itself nested in a tool call.
function terminalTty() {
  let pid = process.ppid
  for (let depth = 0; depth < 2 && pid > 1; depth++) {
    const [ppid, tty] = psRow(pid)
    if (tty && !/^\?+$/.test(tty)) return `/dev/${tty}`
    pid = Number(ppid)
  }
  return null
}

// timeout guards against the hook subprocess blocking forever on a stuck ps
function psRow(pid) {
  try {
    const out = execFileSync("ps", ["-o", "ppid=,tty=", "-p", String(pid)], {
      encoding: "utf-8",
      timeout: 1000,
    })
    return out.trim().split(/\s+/)
  } catch {
    return []
  }
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
  } catch {}
}
