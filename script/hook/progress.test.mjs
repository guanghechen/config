import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, utimesSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import test, { after } from "node:test"
import { fileURLToPath } from "node:url"

const script = fileURLToPath(new URL("progress.mjs", import.meta.url))
const configDir = fileURLToPath(new URL("../../", import.meta.url))
const settings = JSON.parse(readFileSync(path.join(configDir, "settings.json"), "utf8"))
const states = { "\x1b]9;4;3\x07": "busy", "\x1b]9;4;4\x07": "waiting", "\x1b]9;4;0\x07": "idle" }

// The hook resolves the pane tty through `ps`. A stub `ps` names `/dev/..` plus the
// replay's file in $PANE_TTY, so reports land in that file and no real terminal is
// written. One stub serves every replay and runs once up front, because the first exec
// of a new script can outlast the hook's 1s `ps` timeout. The hook splits `ps` output on
// whitespace, so temporary paths must not contain spaces.
const stubBin = mkdtempSync(path.join(tmpdir(), "claude-progress-ps-"))
writeFileSync(path.join(stubBin, "ps"), '#!/bin/sh\necho "1 ..$PANE_TTY"\n')
chmodSync(path.join(stubBin, "ps"), 0o755)
spawnSync(path.join(stubBin, "ps"))
after(() => rmSync(stubBin, { recursive: true, force: true }))

const prompt = { hook_event_name: "UserPromptSubmit" }
const stop = { hook_event_name: "Stop" }
const notice = (type) => ({ hook_event_name: "Notification", notification_type: type })
const idlePrompt = notice("idle_prompt")
const ask = { hook_event_name: "PreToolUse", tool_name: "AskUserQuestion" }
const answer = { hook_event_name: "PostToolUse", tool_name: "AskUserQuestion" }
const batch = { hook_event_name: "PostToolBatch" }
const elicitation = { hook_event_name: "Elicitation", mcp_server_name: "server" }
const elicitationResult = { hook_event_name: "ElicitationResult", mcp_server_name: "server" }
const agentStart = (id) => ({ hook_event_name: "SubagentStart", agent_id: id })
const agentStop = (id) => ({ hook_event_name: "SubagentStop", agent_id: id })
const taskStop = (id) => ({ hook_event_name: "PostToolUse", tool_name: "TaskStop", tool_input: { task_id: id } })
const stopWith = (...tasks) => ({ ...stop, background_tasks: tasks })
const agentStopWith = (id, ...tasks) => ({ ...agentStop(id), background_tasks: tasks })

// Backdates every marker past the window in which the hook spares agents that may have
// started after Claude Code took its snapshot of in-flight work.
function ageMarkers(dir) {
  const markers = path.join(dir, "claude-progress", "session")
  const past = new Date(Date.now() - 60_000)
  for (const name of readdirSync(markers)) utimesSync(path.join(markers, name), past, past)
}

// Postdates every marker, as if each wait began after the next hook process started.
function postdateMarkers(dir) {
  const markers = path.join(dir, "claude-progress", "session")
  const future = new Date(Date.now() + 60_000)
  for (const name of readdirSync(markers)) utimesSync(path.join(markers, name), future, future)
}

// Runs the hook once per event and returns the progress state each run reported; function
// steps run against the hook's TMPDIR in between and report nothing.
function replay(events) {
  const dir = mkdtempSync(path.join(tmpdir(), "claude-progress-hook-"))
  try {
    const tty = path.join(dir, "tty")
    return events.flatMap((event) => {
      if (typeof event === "function") {
        event(dir)
        return []
      }
      rmSync(tty, { force: true })
      const result = spawnSync(process.execPath, [script], {
        input: JSON.stringify({ session_id: "session", ...event }),
        encoding: "utf8",
        env: { ...process.env, PATH: `${stubBin}:${process.env.PATH}`, PANE_TTY: tty, TMPDIR: dir },
        timeout: 5000,
      })
      assert.equal(result.status, 0, result.stderr)
      try {
        return [states[readFileSync(tty, "utf8")] ?? "unknown"]
      } catch {
        return [undefined]
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

test("a denied question clears when the turn continues, closes, or restarts", () => {
  // "Chat about this" continues the turn, so its next batch resumes busy; Esc interrupts
  // the turn without Stop.
  assert.deepEqual(replay([prompt, ask, batch, stop]), ["busy", "waiting", "busy", "idle"])
  assert.deepEqual(replay([prompt, ask, stop]), ["busy", "waiting", "idle"])
  assert.deepEqual(replay([prompt, ask, idlePrompt]), ["busy", "waiting", "idle"])
  assert.deepEqual(replay([prompt, ask, prompt, stop]), ["busy", "waiting", "busy", "idle"])
})

test("a permission dialog waits until the main thread's tool batch resolves", () => {
  assert.deepEqual(replay([prompt, notice("permission_prompt"), batch, stop]), ["busy", "waiting", "busy", "idle"])
})

test("a subagent's tool batch cannot end a wait on the main thread", () => {
  // The subagent's batch reports nothing; its later stop proves the wait survived it.
  assert.deepEqual(
    replay([prompt, agentStart("a1"), ask, { ...batch, agent_id: "a1" }, agentStop("a1"), answer, stop]),
    ["busy", "busy", "waiting", undefined, "waiting", "busy", "idle"],
  )
})

test("an async tool batch spares a wait that began after its hook started", () => {
  assert.deepEqual(replay([prompt, ask, postdateMarkers, batch, stop]), ["busy", "waiting", "waiting", "idle"])
})

test("an MCP elicitation waits until its result arrives", () => {
  assert.deepEqual(replay([prompt, elicitation, elicitationResult, stop]), ["busy", "waiting", "busy", "idle"])
})

test("an exhausted usage limit waits for the user unless Claude resumes on its own", () => {
  for (const type of ["quota_auto_resume_stale", "quota_auto_resume_disabled"]) {
    assert.deepEqual(replay([prompt, stop, notice(type), prompt, stop]), ["busy", "idle", "waiting", "busy", "idle"], type)
  }
  assert.deepEqual(
    replay([prompt, stop, notice("quota_auto_resume_stale"), notice("quota_auto_resume_fired"), stop]),
    ["busy", "idle", "waiting", "busy", "idle"],
  )
})

test("background subagents keep the pane busy until they stop or TaskStop kills them", () => {
  assert.deepEqual(replay([prompt, agentStart("a1"), stop, agentStop("a1")]), ["busy", "busy", "busy", "idle"])
  assert.deepEqual(replay([prompt, agentStart("a1"), taskStop("a1"), stop]), ["busy", "busy", "busy", "idle"])
})

test("agents of a stopped workflow are reaped once no workflow is in flight", () => {
  const workflow = { id: "w1", type: "workflow", status: "running" }
  // TaskStop names only the workflow, so its agents' markers outlive it until Stop reaps them.
  assert.deepEqual(
    replay([prompt, agentStart("a1"), agentStart("a2"), taskStop("w1"), ageMarkers, stopWith()]),
    ["busy", "busy", "busy", "busy", "idle"],
  )
  assert.deepEqual(
    replay([prompt, agentStart("a1"), ageMarkers, stopWith(workflow), agentStart("a2"), agentStopWith("a2")]),
    ["busy", "busy", "busy", "busy", "idle"],
  )
})

test("reaping spares listed subagents and markers newer than the snapshot", () => {
  const live = { id: "a1", type: "subagent", status: "running" }
  assert.deepEqual(
    replay([
      prompt, agentStart("a1"), ageMarkers, agentStart("a2"),
      stopWith(live), agentStopWith("a1"), agentStop("a2"),
    ]),
    ["busy", "busy", "busy", "busy", "busy", "idle"],
  )
})

test("a new session resets the state a killed session stranded on the pane", () => {
  const sessionStart = { hook_event_name: "SessionStart", source: "startup", session_id: "next" }
  assert.deepEqual(replay([prompt, ask, sessionStart]), ["busy", "waiting", "idle"])
})

test("events outside the progress lifecycle leave the pane untouched", () => {
  assert.deepEqual(
    replay([
      { hook_event_name: "PreToolUse", tool_name: "Bash" },
      notice("auth_success"),
      { ...prompt, session_id: undefined },
    ]),
    [undefined, undefined, undefined],
  )
})

test("settings route exactly the notifications with a progress meaning to the hook", () => {
  const groups = settings.hooks.Notification.filter((group) => group.hooks.some((hook) => hook.command.includes("progress.mjs")))
  assert.equal(groups.length, 1)
  const matcher = new RegExp(groups[0].matcher)
  const routed = ["idle_prompt", "permission_prompt", "quota_auto_resume_stale", "quota_auto_resume_disabled", "quota_auto_resume_fired"]
  for (const type of routed) assert.ok(matcher.test(type), type)
  for (const type of ["auth_success", "agent_completed", "elicitation_dialog", "worker_permission_prompt"]) {
    assert.ok(!matcher.test(type), type)
  }
})

test("the PostToolBatch hook starts node only while its own session waits on the user", () => {
  const [{ command, async }] = settings.hooks.PostToolBatch[0].hooks
  // Every tool batch runs this hook, so it stays off the agent loop.
  assert.equal(async, true)
  const dir = mkdtempSync(path.join(tmpdir(), "claude-progress-batch-"))
  try {
    const tty = path.join(dir, "tty")
    const session = path.join(dir, "claude-progress", "session")
    const other = path.join(dir, "claude-progress", "other")
    const { CLAUDE_CODE_SESSION_ID, ...inherited } = process.env
    const runBatch = (sessionId) => {
      rmSync(tty, { force: true })
      const result = spawnSync("sh", ["-c", command], {
        input: JSON.stringify({ session_id: "session", ...batch }),
        encoding: "utf8",
        env: {
          ...inherited,
          ...(sessionId && { CLAUDE_CODE_SESSION_ID: sessionId }),
          CLAUDE_CONFIG_DIR: configDir,
          PATH: `${stubBin}:${process.env.PATH}`,
          PANE_TTY: tty,
          TMPDIR: dir,
        },
        timeout: 5000,
      })
      assert.equal(result.status, 0, result.stderr)
      try {
        return states[readFileSync(tty, "utf8")] ?? "unknown"
      } catch {
        return undefined
      }
    }
    mkdirSync(session, { recursive: true })
    mkdirSync(other, { recursive: true })
    writeFileSync(path.join(session, "turn"), "")
    // Another session's wait, possibly stranded by a killed process, costs this session nothing.
    writeFileSync(path.join(other, "waiting-question"), "")
    assert.equal(runBatch("session"), undefined)
    writeFileSync(path.join(session, "waiting-permission"), "")
    assert.equal(runBatch("session"), "busy")
    assert.deepEqual(readdirSync(session), ["turn"])
    assert.deepEqual(readdirSync(other), ["waiting-question"])
    // Without a session id in the environment, any session's wait starts the hook.
    assert.equal(runBatch(undefined), "busy")
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})
