import assert from "node:assert/strict"
import { spawn, spawnSync } from "node:child_process"
import { once } from "node:events"
import { chmodSync, existsSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import { DatabaseSync } from "node:sqlite"
import { after, test } from "node:test"
import { fileURLToPath } from "node:url"
import { advanceProgress, isWaiting } from "./progress-state.mjs"

const script = fileURLToPath(new URL("progress.mjs", import.meta.url))
const codexHome = fileURLToPath(new URL("../../", import.meta.url))
const states = { "\x1b]9;4;4\x07": "waiting", "\x1b]9;4;0\x07": "idle" }
const temporaryRoot = realpathSync(tmpdir())

// ps points at a fixture file through /dev/..; no test writes a real terminal.
const stubBin = mkdtempSync(path.join(temporaryRoot, "codex-progress-ps-"))
writeFileSync(path.join(stubBin, "ps"), '#!/bin/sh\necho "1 ..$PANE_TTY"\n')
chmodSync(path.join(stubBin, "ps"), 0o755)
spawnSync(path.join(stubBin, "ps"))
after(() => rmSync(stubBin, { recursive: true, force: true }))

const prompt = { name: "UserPromptSubmit" }
const stop = { name: "Stop" }
const interrupt = { name: "Interrupt" }
const ask = { name: "PreToolUse", tool_name: "request_user_input", tool_use_id: "question" }
const answer = { ...ask, name: "PostToolUse" }
const permission = (agent_id) => ({ name: "PermissionRequest", tool_name: "Bash", agent_id })
const model = (agent_id) => ({ name: "PreModelRequest", agent_id })
const agentStop = (agent_id) => ({ name: "SubagentStop", agent_id })
const control = (tool, name = "PreToolUse") => ({
  name, tool_name: "multi_agent_v1" + tool, tool_use_id: "control",
  tool_input: { target: "agent", ...(tool === "send_input" ? { interrupt: true } : {}) },
})
const eventInput = (name, event) => ({
  session_id: "session",
  ...(["SessionStart", "SessionEnd"].includes(name) ? {} : { turn_id: "turn" }),
  ...event,
})

function replay(events) {
  let state = { threads: {}, controls: {} }
  return events.map(({ name, ...event }) => {
    const before = structuredClone(state)
    const next = advanceProgress(state, name, eventInput(name, event))
    assert.deepEqual(state, before, "the core must not mutate its input")
    state = next
    return isWaiting(state) ? "waiting" : "idle"
  })
}

test("permissions clear at the next model request, and questions clear by tool identity", () => {
  assert.deepEqual(replay([prompt, permission(), model(), stop]), ["idle", "waiting", "idle", "idle"])
  assert.deepEqual(replay([
    prompt, ask, { ...ask, tool_use_id: "new-question" }, answer,
    { ...answer, tool_use_id: "new-question" },
  ]), ["idle", "waiting", "waiting", "waiting", "idle"])
})

test("thread completion preserves another thread's wait", () => {
  assert.deepEqual(replay([
    prompt, model("agent"), permission(), permission("agent"), model("agent"), model(),
  ]), ["idle", "idle", "waiting", "waiting", "waiting", "idle"])
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), stop, agentStop("agent"),
  ]), ["idle", "idle", "waiting", "waiting", "idle"])
})

test("late requests cannot revive a stopped or interrupted turn", () => {
  for (const end of [stop, interrupt, { name: "SessionEnd" }]) {
    assert.deepEqual(replay([prompt, permission(), end, permission(), ask]), [
      "idle", "waiting", "idle", "idle", "idle",
    ])
  }
})

test("old terminal events and answers cannot clear a newer turn", () => {
  for (const old of [stop, interrupt, answer, permission()]) {
    assert.deepEqual(replay([
      prompt, { ...prompt, turn_id: "new-turn" }, { ...ask, turn_id: "new-turn" }, old,
    ]), ["idle", "idle", "waiting", "waiting"])
  }
})

test("a blocked Stop can resume model work in the same turn", () => {
  assert.deepEqual(replay([prompt, stop, model(), permission()]), ["idle", "idle", "idle", "waiting"])
})

test("Interrupt during Stop hook processing still clears child waits", () => {
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), stop, interrupt, permission("agent"),
  ]), ["idle", "idle", "waiting", "waiting", "idle", "idle"])
})

test("session boundaries clear waits while compaction preserves them", () => {
  assert.deepEqual(replay([
    prompt, ask, { name: "SessionStart", source: "compact" }, stop,
    { name: "SessionStart", source: "resume" }, prompt, permission(),
  ]), ["idle", "waiting", "waiting", "idle", "idle", "idle", "waiting"])
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), interrupt,
  ]), ["idle", "idle", "waiting", "idle"])
})

test("successful child interruption and closure clear its wait without child lifecycle hooks", () => {
  for (const tool of ["send_input", "close_agent"]) {
    assert.deepEqual(replay([
      prompt, model("agent"), permission("agent"), control(tool),
      control(tool, "PostToolUse"), permission("agent"), stop,
      { ...prompt, turn_id: "next-root-turn" }, { ...model(), turn_id: "next-root-turn" },
    ]), ["idle", "idle", "waiting", "waiting", "idle", "idle", "idle", "idle", "idle"])
  }
})

test("a control call cannot clear a child's resumed turn", () => {
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), control("send_input"),
    { ...model("agent"), turn_id: "resumed" }, { ...permission("agent"), turn_id: "resumed" },
    control("send_input", "PostToolUse"), agentStop("agent"),
  ]), ["idle", "idle", "waiting", "waiting", "idle", "waiting", "waiting", "waiting"])
})

test("successful closure clears children that started or advanced while the call was in flight", () => {
  assert.deepEqual(replay([
    prompt, control("close_agent"), model("agent"), permission("agent"),
    control("close_agent", "PostToolUse"), stop,
  ]), ["idle", "idle", "idle", "waiting", "idle", "idle"])
  assert.deepEqual(replay([
    prompt, model("agent"), control("close_agent"),
    { ...model("agent"), turn_id: "advanced" }, { ...permission("agent"), turn_id: "advanced" },
    control("close_agent", "PostToolUse"),
  ]), ["idle", "idle", "idle", "idle", "waiting", "idle"])
})

test("failed controls and queued input leave the live child's wait intact", () => {
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), control("close_agent"), model(),
  ]), ["idle", "idle", "waiting", "waiting", "waiting"])
  const queued = { ...control("send_input"), tool_input: { target: "agent", interrupt: false } }
  assert.deepEqual(replay([
    prompt, model("agent"), permission("agent"), queued, { ...queued, name: "PostToolUse" },
  ]), ["idle", "idle", "waiting", "waiting", "waiting"])
})

function fixture(t) {
  const dir = mkdtempSync(path.join(temporaryRoot, "codex-progress-hook-"))
  const tty = path.join(dir, "tty")
  const children = new Set()
  const env = { ...process.env, PATH: stubBin + ":" + process.env.PATH, PANE_TTY: tty, TMPDIR: dir }
  t.after(async () => {
    await Promise.all([...children].map(async (child) => {
      const exit = once(child, "exit")
      child.kill("SIGKILL")
      await exit
    }))
    rmSync(dir, { recursive: true, force: true })
  })

  function run({ name, ...event }) {
    rmSync(tty, { force: true })
    const result = spawnSync(process.execPath, [script, name], {
      input: JSON.stringify(eventInput(name, event)), encoding: "utf8", env, timeout: 5000,
    })
    assert.equal(result.status, 0, result.stderr)
    return readFileSync(tty, "utf8")
  }

  function start({ name, ...event }) {
    const child = spawn(process.execPath, [script, name], { env })
    children.add(child)
    let stderr = ""
    child.stderr.on("data", (chunk) => { stderr += chunk })
    const done = once(child, "exit").then(([code, signal]) => {
      children.delete(child)
      assert.equal(code, 0, stderr || signal)
    })
    return { done, release: () => child.stdin.end(JSON.stringify(eventInput(name, event))) }
  }

  function database() {
    const root = path.join(dir, "codex-progress")
    const file = readdirSync(root).find((name) => name.endsWith(".sqlite"))
    return path.join(root, file)
  }

  function state() {
    const db = new DatabaseSync(database(), { readOnly: true })
    try {
      return JSON.parse(db.prepare("SELECT value FROM state WHERE id = 1").get().value)
    } finally {
      db.close()
    }
  }

  return { dir, tty, env, run, start, database, state }
}

test("the command reports real state transitions to a fake TTY", (t) => {
  const f = fixture(t)
  assert.deepEqual([prompt, permission(), model(), ask, answer, stop].map((event) => states[f.run(event)]), [
    "idle", "waiting", "idle", "waiting", "idle", "idle",
  ])
})

test("real session boundary payloads without turn_id clear persisted child waits", (t) => {
  for (const boundary of [{ name: "SessionEnd", reason: "other" }, { name: "SessionStart", source: "resume" }]) {
    const f = fixture(t)
    f.run(model("agent"))
    f.run(permission("agent"))
    assert.equal(states[f.run(boundary)], "idle")
    assert.equal(isWaiting(f.state()), false)
    assert.equal(states[f.run(prompt)], "idle")
  }
})

test("the command clears child waits when interrupted during Stop", (t) => {
  const f = fixture(t)
  for (const event of [prompt, model("agent"), permission("agent"), stop]) f.run(event)
  assert.equal(states[f.run(interrupt)], "idle")
  assert.equal(isWaiting(f.state()), false)
})

test("a delayed permission process cannot restore waiting after Stop", async (t) => {
  const f = fixture(t)
  f.run(prompt)
  const late = f.start(permission())
  f.run(stop)
  late.release()
  await late.done
  assert.equal(states[readFileSync(f.tty, "utf8")], "idle")
  assert.equal(isWaiting(f.state()), false)
})

test("a delayed Interrupt process cannot delete the next turn's wait", async (t) => {
  const f = fixture(t)
  f.run(prompt)
  const late = f.start(interrupt)
  f.run({ ...prompt, turn_id: "new-turn" })
  f.run({ ...permission(), turn_id: "new-turn" })
  late.release()
  await late.done
  assert.equal(states[readFileSync(f.tty, "utf8")], "waiting")
  assert.equal(isWaiting(f.state()), true)
})

test("control hook replay clears a cancelled child and preserves a resumed child", (t) => {
  const f = fixture(t)
  for (const event of [prompt, model("agent"), permission("agent"), control("send_input")]) f.run(event)
  assert.equal(states[f.run(control("send_input", "PostToolUse"))], "idle")
  f.run({ ...model("agent"), turn_id: "second" })
  f.run({ ...permission("agent"), turn_id: "second" })
  f.run({ ...control("send_input"), tool_use_id: "second-control" })
  f.run({ ...model("agent"), turn_id: "third" })
  f.run({ ...permission("agent"), turn_id: "third" })
  assert.equal(states[f.run({
    ...control("send_input", "PostToolUse"), tool_use_id: "second-control",
  })], "waiting")
})

test("successful close reports idle for a child that started or advanced while closing", (t) => {
  const f = fixture(t)
  f.run(prompt)
  // close_agent needs only the successful PostToolUse; no earlier child snapshot exists.
  f.run(model("agent"))
  f.run(permission("agent"))
  assert.equal(states[f.run(control("close_agent", "PostToolUse"))], "idle")
  f.run({ ...model("agent"), turn_id: "second" })
  f.run({ ...permission("agent"), turn_id: "second" })
  assert.equal(states[f.run(control("close_agent", "PostToolUse"))], "idle")
  assert.equal(isWaiting(f.state()), false)
})

test("concurrent threads retain all waits and leave the final TTY state consistent", async (t) => {
  const f = fixture(t)
  const agents = ["a", "b", "c", "d"]
  for (const agent of agents) f.run(model(agent))
  const waits = agents.map((agent) => f.start(permission(agent)))
  for (const wait of waits) wait.release()
  await Promise.all(waits.map((wait) => wait.done))
  assert.equal(Object.values(f.state().threads).filter((thread) => thread.permission).length, agents.length)
  assert.equal(states[readFileSync(f.tty, "utf8")], "waiting")

  const stops = agents.map((agent) => f.start(agentStop(agent)))
  for (const stop of stops) stop.release()
  await Promise.all(stops.map((stop) => stop.done))
  assert.equal(isWaiting(f.state()), false)
  assert.equal(states[readFileSync(f.tty, "utf8")], "idle")
})

test("a killed transaction rolls back and releases its lock for subsequent hooks", async (t) => {
  const f = fixture(t)
  f.run(prompt)
  const owner = spawn(process.execPath, ["--input-type=module", "-e", [
    'import { DatabaseSync } from "node:sqlite";',
    'const db = new DatabaseSync(process.argv[1]);',
    'db.exec("BEGIN IMMEDIATE");',
    'db.exec("DELETE FROM state");',
    'process.stdout.write("locked");',
    'setInterval(() => {}, 1000);',
  ].join("\n"), f.database()])
  try {
    await once(owner.stdout, "data")
  } finally {
    const exited = once(owner, "exit")
    owner.kill("SIGKILL")
    await exited
  }
  assert.equal(states[f.run(permission())], "waiting")
  assert.equal(f.state().threads.main.turnId, "turn")
})

test("a hook that cannot take the lock exits cleanly and logs why", async (t) => {
  const f = fixture(t)
  f.run(prompt)
  const owner = spawn(process.execPath, ["--input-type=module", "-e", [
    'import { DatabaseSync } from "node:sqlite";',
    'const db = new DatabaseSync(process.argv[1]);',
    'db.exec("BEGIN IMMEDIATE");',
    'process.stdout.write("locked");',
    'setInterval(() => {}, 1000);',
  ].join("\n"), f.database()])
  try {
    await once(owner.stdout, "data")
    rmSync(f.tty, { force: true })
    const { name, ...event } = permission()
    const result = spawnSync(process.execPath, [script, name], {
      input: JSON.stringify(eventInput(name, event)), encoding: "utf8", env: f.env, timeout: 5000,
    })
    assert.equal(result.status, 0)
    assert.equal(result.stderr, "")
    assert.equal(existsSync(f.tty), false, "a failed update reports nothing")
    const log = readFileSync(path.join(f.dir, "codex-progress", "error.log"), "utf8")
    assert.match(log, /PermissionRequest: database is locked/)
  } finally {
    const exited = once(owner, "exit")
    owner.kill("SIGKILL")
    await exited
  }
})

test("configured state hooks are synchronous and respect lifecycle timeout limits", () => {
  const config = readFileSync(path.join(codexHome, "config.shared.toml"), "utf8")
  const handlers = [...config.matchAll(/\[\[hooks\.(\w+)\.hooks\]\]\n([\s\S]*?)(?=\n\[|$)/g)]
    .filter(([, , body]) => body.includes("/script/hook/progress.mjs"))
  assert.deepEqual(handlers.map(([, name]) => name).sort(), [
    "PermissionRequest", "PreToolUse", "PostToolUse", "PreModelRequest",
    "UserPromptSubmit", "Stop", "SubagentStop", "Interrupt", "SessionStart", "SessionEnd",
  ].sort())
  for (const [, name, body] of handlers) {
    assert.doesNotMatch(body, /async\s*=\s*true/, name)
    assert.equal(Number(body.match(/timeout\s*=\s*(\d+)/)[1]), ["Interrupt", "SessionEnd"].includes(name) ? 3 : 5)
  }
  for (const name of ["PreToolUse", "PostToolUse"]) {
    const groups = [...config.matchAll(new RegExp("\\[\\[hooks\\." + name + "\\]\\]\\nmatcher = \"([^\"]+)\"", "g"))]
    const matchers = groups.map(([, matcher]) => new RegExp(matcher))
    const tools = ["request_user_input", "multi_agent_v1send_input"]
    if (name === "PostToolUse") tools.push("multi_agent_v1close_agent")
    for (const tool of tools) {
      assert.ok(matchers.some((matcher) => matcher.test(tool)), name + ": " + tool)
    }
  }
})
