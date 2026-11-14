#!/usr/bin/env node

import { createHash } from "node:crypto"
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { DatabaseSync } from "node:sqlite"
import { advanceProgress, isWaiting } from "./progress-state.mjs"
import { terminalTty } from "./tty.mjs"

// Codex reports work through its title spinner. Report waits as OSC 9;4 paused
// progress, which tmux captures as pane_pb_state (its OSC 7501 state is dropped).
// Synchronous hooks order events within a thread; one SQLite transaction covers
// the state update and TTY report across threads, and releases its lock on exit.
//
// The state remains approximate: approvals clear at the next model request;
// MCP elicitations, sign-in prompts, request_user_input_async and plan-mode prompts
// have no corresponding blocking hook. Child cancellation uses the successful
// multi_agent_v1 control call because child Interrupt/SessionEnd hooks do not run.
// Only those v1 controls are tracked: a child cancelled through multi-agent v2
// (interrupt_agent, or its unnamespaced close_agent) keeps its wait until a root
// interrupt or session boundary. close_agent also closes the target's descendants
// without clearing their waits; [agents] max_depth = 1 leaves children none.
const WAITING = "\x1b]9;4;4\x07"
const IDLE = "\x1b]9;4;0\x07"
const EVENTS = new Set([
  "PermissionRequest", "PreToolUse", "PostToolUse", "PreModelRequest",
  "UserPromptSubmit", "Stop", "SubagentStop", "Interrupt", "SessionStart", "SessionEnd",
])

main()

function main() {
  const name = process.argv[2]
  const event = readEvent()
  if (!EVENTS.has(name) || typeof event?.session_id !== "string") return
  // Session boundaries omit turn_id from hook stdin even though the host's
  // internal request carries one for hook run tracking.
  if (name !== "SessionStart" && name !== "SessionEnd" && typeof event.turn_id !== "string") return
  if (name === "SessionStart" && event.source === "compact") return
  if ((name === "PreToolUse" || name === "PostToolUse") && ![
    "request_user_input", "multi_agent_v1send_input", "multi_agent_v1close_agent",
  ].includes(event.tool_name)) return

  // Resolve the terminal before taking the transaction lock: ps can take up to 2s.
  const tty = terminalTty()
  const dir = join(tmpdir(), "codex-progress")
  let db
  try {
    mkdirSync(dir, { recursive: true, mode: 0o700 })
    const session = createHash("sha256").update(event.session_id).digest("hex")
    db = new DatabaseSync(join(dir, `${session}.sqlite`), { timeout: 1000 })
    db.exec("CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK (id = 1), value TEXT NOT NULL)")
    db.exec("BEGIN IMMEDIATE")
    const row = db.prepare("SELECT value FROM state WHERE id = 1").get()
    const state = row ? JSON.parse(row.value) : { threads: {}, controls: {} }
    const next = advanceProgress(state, name, event)
    db.prepare("INSERT INTO state VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET value = excluded.value")
      .run(JSON.stringify(next))
    if (tty) tryWrite(tty, isWaiting(next) ? WAITING : IDLE)
    db.exec("COMMIT")
  } catch (error) {
    // Progress is best effort: a failed hook would stay in Codex's transcript, while a
    // lost update costs only this event's report. Keep the reason for debugging.
    try {
      appendFileSync(join(dir, "error.log"), `${new Date().toISOString()} ${name}: ${error.message}\n`)
    } catch {}
  } finally {
    // Closing inside the transaction rolls it back.
    db?.close()
  }
}

function readEvent() {
  try {
    return JSON.parse(readFileSync(0, "utf-8"))
  } catch {
    return null
  }
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
  } catch {}
}
