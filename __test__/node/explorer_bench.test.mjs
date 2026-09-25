import assert from "node:assert/strict"
import test from "node:test"
import { summarize } from "../bench/explorer/analyze.mjs"

function run(trial, cursorTimes, mode = "tree") {
  const memory = { rss_kib: 10240, lua_heap_kib: 1024 }
  return {
    schema_version: 1,
    trial,
    mode,
    case: "example",
    implementation: "native",
    operations: [{ kind: "open", ready_ms: 20 }, ...cursorTimes.map((time) => ({ kind: "cursor", visible_ms: time }))],
    baseline: memory,
    open_memory: memory,
    final_memory: memory,
  }
}

test("repeated operations do not become independent trials or outweigh another process", () => {
  const result = summarize([run(1, [1, 1, 1, 1, 1]), run(2, [9])])
  assert.deepEqual(result.groups[0].metrics["cursor.visible_ms"], {
    runs: 2,
    observations: 6,
    median: 5,
    min: 1,
    max: 9,
  })
  assert.equal(result.groups[0].metrics["open_memory.rss_mib"].median, 10)
  assert.equal(result.groups[0].metrics["open.ready_ms"].p95, undefined)
})

test("Tree and List remain separate and appended duplicate trials are rejected", () => {
  assert.equal(summarize([run(1, [1]), run(1, [9], "list")]).groups.length, 2)
  assert.throws(() => summarize([run(1, [1]), run(1, [9])]), /duplicate run/)
  assert.throws(() => summarize([run(1, [NaN])]), /invalid metric/)
})

test("cold expansion and repeated warm expansion have distinct statistics", () => {
  const trial = run(1, [1])
  trial.operations.push(
    { kind: "expand", visible_ms: 100 },
    { kind: "expand", visible_ms: 4 },
    { kind: "expand", visible_ms: 6 },
  )
  const metrics = summarize([trial]).groups[0].metrics
  assert.equal(metrics["expand_cold.visible_ms"].median, 100)
  assert.equal(metrics["expand_warm.visible_ms"].median, 5)
  assert.equal(metrics["expand_warm.visible_ms"].observations, 2)
})
