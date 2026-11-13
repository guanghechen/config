#!/usr/bin/env node

import { mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { terminalTty } from "./tty.mjs"

// Claude Code keeps a static terminal title under multiplexers, so a busy pane looks
// idle. Report activity as an OSC 9;4 progress state instead; tmux captures it as
// pane_pb_state. Background subagents outlive the turn, so busy means an open turn or
// any live subagent, tracked as one marker file each under a per-session directory.
// Anything that blocks the session on the user (a question, a permission dialog, an MCP
// elicitation, an exhausted usage limit) keeps a waiting-* marker, reports paused, and
// outranks busy: the user is needed even while subagents run.
const BUSY = "\x1b]9;4;3\x07"
const WAITING = "\x1b]9;4;4\x07"
const IDLE = "\x1b]9;4;0\x07"

main()

function main() {
  const event = readEvent()
  if (!event?.session_id) return
  const dir = join(tmpdir(), "claude-progress", event.session_id)
  const name = event.hook_event_name
  const marker = join(dir, name.startsWith("Subagent") ? `agent-${event.agent_id}` : "turn")
  const waiting = (kind) => join(dir, `waiting-${kind}`)
  const topic = event.tool_name ?? event.notification_type

  switch (topic ? `${name}:${topic}` : name) {
    case "UserPromptSubmit":
      touch(marker)
      clearWaits(dir)
      break
    case "SubagentStart":
      touch(marker)
      break
    // Stop is skipped on user interrupt; idle_prompt is the fallback that closes the turn.
    case "Stop":
    case "StopFailure":
    case "Notification:idle_prompt":
      rmSync(marker, { force: true })
      clearWaits(dir)
      reapAgents(dir, event.background_tasks)
      break
    case "SubagentStop":
      rmSync(marker, { force: true })
      reapAgents(dir, event.background_tasks)
      break
    // The bell alone cannot mark a wait on the user: tmux records none on a visible window
    // and clears it once viewed. Each wait therefore keeps a marker until its own end event,
    // a resolved main-thread tool batch, or a turn boundary clears it.
    case "PreToolUse:AskUserQuestion":
      touch(waiting("question"))
      break
    case "PostToolUse:AskUserQuestion":
      rmSync(waiting("question"), { force: true })
      break
    // No event marks the user's decision on a permission dialog, so an approved tool keeps
    // reporting waiting until its batch resolves.
    case "Notification:permission_prompt":
      touch(waiting("permission"))
      break
    case "Elicitation":
      touch(waiting("elicitation"))
      break
    case "ElicitationResult":
      rmSync(waiting("elicitation"), { force: true })
      break
    // An exhausted usage limit has already ended the turn. Stale and disabled notices need
    // the user to continue; the fired notice means Claude resumed the task on its own.
    case "Notification:quota_auto_resume_stale":
    case "Notification:quota_auto_resume_disabled":
      touch(waiting("quota"))
      break
    case "Notification:quota_auto_resume_fired":
      rmSync(waiting("quota"), { force: true })
      touch(marker)
      break
    // A batch resolves only after every dialog it raised, which also covers a denied
    // question ("Chat about this") that continues the turn. A subagent's batch carries
    // agent_id and cannot resolve the main thread's dialogs. The hook runs async, so it
    // spares waits that began after it started.
    case "PostToolBatch":
      if (event.agent_id) return
      clearWaits(dir, performance.timeOrigin)
      break
    // TaskStop kills a subagent without firing SubagentStop; its task_id is the agent_id.
    case "PostToolUse:TaskStop":
      rmSync(join(dir, `agent-${event.tool_input?.task_id}`), { force: true })
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
  if (tty) tryWrite(tty, progressOf(dir))
}

function readEvent() {
  try {
    return JSON.parse(readFileSync(0, "utf-8"))
  } catch {
    return null
  }
}

function touch(file) {
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, "")
}

function clearWaits(dir, before = Infinity) {
  let markers
  try {
    markers = readdirSync(dir)
  } catch {
    return
  }
  for (const name of markers) {
    if (!name.startsWith("waiting-")) continue
    const file = join(dir, name)
    try {
      if (statSync(file).mtimeMs < before) rmSync(file, { force: true })
    } catch {}
  }
}

// Claude Code skips SubagentStop for a subagent aborted mid-query, as TaskStop on the agent
// or its workflow does, and TaskStop names only the task it stopped. Stop and SubagentStop
// list the session's in-flight background work, so an agent marker missing from that list
// is stale. Workflow agents are not listed one by one, so reaping waits until no workflow
// is in flight, and it spares markers younger than Claude Code's snapshot could know about.
function reapAgents(dir, tasks) {
  if (!Array.isArray(tasks)) return
  const inFlight = tasks.filter((task) => task && !["completed", "failed", "killed"].includes(task.status))
  if (inFlight.some((task) => task.type === "workflow")) return
  const live = new Set(inFlight.filter((task) => task.type === "subagent").map((task) => `agent-${task.id}`))
  const fresh = Date.now() - 10_000
  let markers
  try {
    markers = readdirSync(dir)
  } catch {
    return
  }
  for (const name of markers) {
    if (!name.startsWith("agent-") || live.has(name)) continue
    const file = join(dir, name)
    try {
      if (statSync(file).mtimeMs < fresh) rmSync(file, { force: true })
    } catch {}
  }
}

function progressOf(dir) {
  let markers
  try {
    markers = readdirSync(dir)
  } catch {
    return IDLE
  }
  if (markers.some((name) => name.startsWith("waiting-"))) return WAITING
  return markers.length > 0 ? BUSY : IDLE
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
  } catch {}
}
