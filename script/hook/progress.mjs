#!/usr/bin/env node

import { mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { terminalTty } from "./tty.mjs"

// Claude Code keeps a static terminal title under multiplexers, so a busy pane looks
// idle. Report activity as an OSC 9;4 progress state instead; tmux captures it as
// pane_pb_state. Background subagents outlive the turn, so busy means an open turn or
// any live subagent, tracked as one marker file each under a per-session directory.
// A pending question reports paused and outranks busy: the user is needed even while
// subagents run.
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
  const question = join(dir, "question")

  switch (event.tool_name ? `${name}:${event.tool_name}` : name) {
    case "UserPromptSubmit":
      mkdirSync(dir, { recursive: true })
      writeFileSync(marker, "")
      rmSync(question, { force: true })
      break
    case "SubagentStart":
      mkdirSync(dir, { recursive: true })
      writeFileSync(marker, "")
      break
    // Stop is skipped on user interrupt; idle_prompt is the fallback that closes the turn.
    case "Stop":
    case "StopFailure":
    case "Notification":
      rmSync(marker, { force: true })
      rmSync(question, { force: true })
      reapAgents(dir, event.background_tasks)
      break
    case "SubagentStop":
      rmSync(marker, { force: true })
      reapAgents(dir, event.background_tasks)
      break
    // The bell alone cannot mark a pending question: tmux records none on a visible window
    // and clears it once viewed. Declining or "Chat about this" denies the tool without
    // PostToolUse, so the turn boundaries above clear the question as well.
    case "PreToolUse:AskUserQuestion":
      mkdirSync(dir, { recursive: true })
      writeFileSync(question, "")
      break
    case "PostToolUse:AskUserQuestion":
      rmSync(question, { force: true })
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
  if (markers.includes("question")) return WAITING
  return markers.length > 0 ? BUSY : IDLE
}

function tryWrite(target, data) {
  try {
    writeFileSync(target, data)
  } catch {}
}
