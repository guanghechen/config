import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"

const script = fileURLToPath(new URL("progress.mjs", import.meta.url))
const states = { "\x1b]9;4;3\x07": "busy", "\x1b]9;4;4\x07": "waiting", "\x1b]9;4;0\x07": "idle" }

const prompt = { hook_event_name: "UserPromptSubmit" }
const stop = { hook_event_name: "Stop" }
const idlePrompt = { hook_event_name: "Notification", notification_type: "idle_prompt" }
const ask = { hook_event_name: "PreToolUse", tool_name: "AskUserQuestion" }
const answer = { hook_event_name: "PostToolUse", tool_name: "AskUserQuestion" }
const agentStart = (id) => ({ hook_event_name: "SubagentStart", agent_id: id })
const agentStop = (id) => ({ hook_event_name: "SubagentStop", agent_id: id })
const taskStop = (id) => ({ hook_event_name: "PostToolUse", tool_name: "TaskStop", tool_input: { task_id: id } })

// Runs the hook once per event and returns the progress state each run reported. A stub
// `ps` names `/dev/..` plus a plain file as the pane tty, so reports land in that file and
// no real terminal is written. The hook splits `ps` output on whitespace, so the
// temporary path must not contain spaces.
function replay(events) {
  const dir = mkdtempSync(path.join(tmpdir(), "claude-progress-hook-"))
  try {
    const tty = path.join(dir, "tty")
    const bin = path.join(dir, "bin")
    mkdirSync(bin)
    writeFileSync(path.join(bin, "ps"), `#!/bin/sh\necho "1 ..${tty}"\n`)
    chmodSync(path.join(bin, "ps"), 0o755)
    return events.map((event) => {
      rmSync(tty, { force: true })
      const result = spawnSync(process.execPath, [script], {
        input: JSON.stringify({ session_id: "session", ...event }),
        encoding: "utf8",
        env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TMPDIR: dir },
        timeout: 5000,
      })
      assert.equal(result.status, 0, result.stderr)
      try {
        return states[readFileSync(tty, "utf8")] ?? "unknown"
      } catch {
        return undefined
      }
    })
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

test("a pending question reports waiting until the answer resumes the turn", () => {
  assert.deepEqual(replay([prompt, ask, answer, stop]), ["busy", "waiting", "busy", "idle"])
})

test("a pending question outranks live subagents and outlasts their exit", () => {
  assert.deepEqual(
    replay([prompt, agentStart("a1"), ask, agentStop("a1"), answer, stop]),
    ["busy", "busy", "waiting", "waiting", "busy", "idle"],
  )
})

test("a denied question clears when the turn closes or restarts", () => {
  // "Chat about this" continues the turn until Stop; Esc interrupts it without Stop.
  assert.deepEqual(replay([prompt, ask, stop]), ["busy", "waiting", "idle"])
  assert.deepEqual(replay([prompt, ask, idlePrompt]), ["busy", "waiting", "idle"])
  assert.deepEqual(replay([prompt, ask, prompt, stop]), ["busy", "waiting", "busy", "idle"])
})

test("background subagents keep the pane busy until they stop or TaskStop kills them", () => {
  assert.deepEqual(replay([prompt, agentStart("a1"), stop, agentStop("a1")]), ["busy", "busy", "busy", "idle"])
  assert.deepEqual(replay([prompt, agentStart("a1"), taskStop("a1"), stop]), ["busy", "busy", "busy", "idle"])
})

test("a new session resets the state a killed session stranded on the pane", () => {
  const sessionStart = { hook_event_name: "SessionStart", source: "startup", session_id: "next" }
  assert.deepEqual(replay([prompt, ask, sessionStart]), ["busy", "waiting", "idle"])
})

test("events outside the progress lifecycle leave the pane untouched", () => {
  assert.deepEqual(
    replay([{ hook_event_name: "PreToolUse", tool_name: "Bash" }, { ...prompt, session_id: undefined }]),
    [undefined, undefined],
  )
})
