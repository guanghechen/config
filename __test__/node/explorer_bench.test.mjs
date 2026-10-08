import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"
import { analyze, summarize, summarizeProbes } from "../../script/benchmark/explorer-report.mjs"
import { inputFingerprint, measuredRepository, parseStatus, probeArguments } from "../../script/benchmark/explorer.mjs"

function run(trial, cursorTimes, mode = "tree") {
  const memory = { process_memory_bytes: 10485760, process_memory_kind: "physical_footprint", lua_heap_kib: 1024 }
  return {
    schema_version: 2,
    input_fingerprint: "a".repeat(64),
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
    maximum_observation: 9,
  })
  assert.equal(result.groups[0].metrics["open_memory.process_memory_mib"].median, 10)
  assert.equal(result.groups[0].memory_kind, "physical_footprint")
  assert.equal(result.groups[0].metrics["open.ready_ms"].p95, undefined)
})

test("a slow individual input remains visible after reducing each process to its median", () => {
  const first = run(1, [1, 1, 1000])
  const second = run(2, [2, 2, 3])
  first.operations[1].observer_rpcs = 0
  first.operations[1].readiness_checks = 4
  const result = summarize([first, second]).groups[0].metrics
  assert.equal(result["cursor.visible_ms"].median, 1.5)
  assert.equal(result["cursor.visible_ms"].max, 2)
  assert.equal(result["cursor.visible_ms"].maximum_observation, 1000)
  assert.equal(result["cursor.observer_rpcs"].maximum_observation, 0)
  assert.equal(result["cursor.readiness_checks"].median, 4)
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

test("source fingerprints, measurement scopes and memory definitions cannot be mixed", () => {
  assert.throws(() => summarize([run(1, [1]), { ...run(2, [1]), input_fingerprint: "b".repeat(64) }]), /mixed input fingerprints/)
  assert.throws(() => summarize([{ ...run(1, [1]), input_fingerprint: undefined }]), /input fingerprint/)
  assert.throws(() => summarize([run(1, [1]), { ...run(2, [1]), scope: "startup" }]), /mixed measurement scopes/)
  const differentMemory = run(2, [1])
  differentMemory.baseline.process_memory_kind = "rss"
  assert.throws(() => summarize([run(1, [1]), differentMemory]), /incompatible memory/)
})

test("porcelain metadata preserves unusual paths and consumes rename sources", () => {
  assert.deepEqual(parseStatus(" M -file\nname.lua\0R  renamed.lua\0old\nname.lua\0?? \nfile.lua\0"), [
    { status: " M", path: "-file\nname.lua" },
    { status: "R ", path: "renamed.lua", from: "old\nname.lua" },
    { status: "??", path: "\nfile.lua" },
  ])
  assert.deepEqual(parseStatus(""), [])
  assert.throws(() => parseStatus(" M file"), /unterminated/)
  assert.throws(() => parseStatus("R  renamed\0"), /missing.*source/)
  assert.throws(() => parseStatus(" M file\0\0"), /invalid.*entry/)
})

test("probe arguments preserve requested process samples and native-only idle", () => {
  const options = { samples: 100, repeats: 3, cycles: 200, lsp: "/vtsls" }
  assert.deepEqual(probeArguments("idle", options), ["-", "100"])
  assert.deepEqual(probeArguments("root_watch", options), ["100"])
  assert.deepEqual(probeArguments("active_loading", options), ["100", "50000"])
  assert.deepEqual(probeArguments("jobs_ui", options), ["100"])
  assert.deepEqual(probeArguments("full_config", options), ["100", "120"])
  assert.deepEqual(probeArguments("soak", options), ["200", "1000"])
})

test("active loading keeps modes and cold versus warm scans in separate process groups", () => {
  const groups = summarizeProbes({ active_loading: [{ records: [
    { trial: 1, mode: "tree", phase: "cold", input_visible_ms: 4 },
    { trial: 2, mode: "tree", phase: "cold", input_visible_ms: 8 },
    { trial: 1, mode: "tree", phase: "warm", input_visible_ms: 1 },
    { trial: 1, mode: "list", phase: "cold", input_visible_ms: 14 },
  ] }] })
  assert.equal(groups.length, 3)
  const cold = groups.find(group => group.scenario === "tree_cold").metrics.input_visible_ms
  assert.equal(cold.runs, 2)
  assert.equal(cold.median, 6)
  assert.equal(cold.p95, undefined)
  assert.equal(groups.find(group => group.scenario === "tree_warm").metrics.input_visible_ms.median, 1)
  assert.equal(groups.find(group => group.scenario === "list_cold").metrics.input_visible_ms.median, 14)
})

test("fingerprints ignore JSON field ordering while retaining measurement and plugin changes", () => {
  const first = { plugins: [{ name: "plugin", loaded: true }], measurement: { repeats: 3, nvim: "0.12" } }
  const reordered = { measurement: { nvim: "0.12", repeats: 3 }, plugins: [{ loaded: true, name: "plugin" }] }
  assert.equal(inputFingerprint(first), inputFingerprint(reordered))
  assert.notEqual(inputFingerprint(first), inputFingerprint({ ...first, measurement: { ...first.measurement, repeats: 4 } }))
  assert.notEqual(inputFingerprint(first), inputFingerprint({ ...first, plugins: [{ name: "plugin", loaded: false }] }))
})

test("Git staging does not change measured contents, but source and native changes do", () => {
  const repository = { path: "/checkout", head: "head", worktree: [{ status: " M", path: "lua/file.lua" }],
    native_module: "/yoz.so", provenance: { artifact_sha256: "native" }, runtime: { sha256: "runtime" } }
  const before = inputFingerprint(measuredRepository(repository))
  assert.equal(before, inputFingerprint(measuredRepository({ ...repository, worktree: [{ status: "M ", path: "lua/file.lua" }] })))
  assert.notEqual(before, inputFingerprint(measuredRepository({ ...repository, runtime: { sha256: "changed" } })))
  assert.notEqual(before, inputFingerprint(measuredRepository({ ...repository, provenance: { artifact_sha256: "rebuilt" } })))
})

test("failed and partial runs still produce an honest report", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "explorer-report-test-"))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  writeFileSync(join(directory, "metadata.json"), JSON.stringify({
    status: "failed", repositories: {}, samples: 3,
    coverage: [{ case: "example", comparison: "legacy/native", status: "failed", reason: "second process failed" },
      { case: "lsp", comparison: "native", status: "blocked", reason: "missing server" }],
  }))
  assert.deepEqual(analyze(directory).groups, [])
  let report = readFileSync(join(directory, "report.md"), "utf8")
  assert.match(report, /Run status: failed\. Comparable process records: 0/)
  assert.match(report, /blocked.*missing server/)
  writeFileSync(join(directory, "results.jsonl"), JSON.stringify(run(1, [3])) + "\n")
  const summary = analyze(directory)
  assert.equal(summary.groups[0].metrics["cursor.visible_ms"].runs, 1)
  report = readFileSync(join(directory, "report.md"), "utf8")
  assert.match(report, /Run status: failed\. Comparable process records: 1/)
  assert.match(report, /failed.*second process failed/)
})

test("selection reports distinguish first UI feedback from decoration completion", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "explorer-selection-report-"))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  writeFileSync(join(directory, "metadata.json"), JSON.stringify({ status: "complete", repositories: {}, coverage: [] }))
  const trial = run(1, [3])
  trial.operations.push(
    { kind: "selection", visible_ms: 5, ready_ms: 1500, observer_rpcs: 0 },
    { kind: "visual_selection", visible_ms: 8, ready_ms: 1700, observer_rpcs: 0 },
  )
  writeFileSync(join(directory, "results.jsonl"), JSON.stringify(trial) + "\n")
  const metrics = analyze(directory).groups[0].metrics
  assert.equal(metrics["selection.visible_ms"].median, 5)
  assert.equal(metrics["selection.ready_ms"].median, 1500)
  const report = readFileSync(join(directory, "report.md"), "utf8")
  assert.match(report, /Selection flush \| Visual selection flush/)
  assert.match(report, /\| selection \| 1 \| 5\.000 \|/)
  assert.match(report, /\| visual_selection \| 1 \| 8\.000 \|/)
  assert.doesNotMatch(report, /\| selection \| 1 \| 1500\.000 \|/)
})

test("historical selection ready values cannot masquerade as first UI feedback", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "explorer-old-selection-report-"))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  writeFileSync(join(directory, "metadata.json"), JSON.stringify({ status: "complete", repositories: {}, coverage: [] }))
  const trial = run(1, [3])
  trial.operations.push({ kind: "selection", ready_ms: 1500 }, { kind: "visual_selection", ready_ms: 1700 })
  writeFileSync(join(directory, "results.jsonl"), JSON.stringify(trial) + "\n")
  const metrics = analyze(directory).groups[0].metrics
  assert.equal(metrics["selection.visible_ms"], undefined)
  assert.equal(metrics["selection.ready_ms"].median, 1500)
  const report = readFileSync(join(directory, "report.md"), "utf8")
  assert.doesNotMatch(report, /\| (?:visual_)?selection \| 1 \|/)
  assert.match(report, /Historical records without a selection flush remain unavailable/)
})

test("watch events stay within their process and idle phases stay separate", () => {
  const groups = summarizeProbes({
    watch: [{ memory_measurement: { kind: "physical_footprint" }, records: [
      { trial: 1, kind: "continuous", visible_ms: [1, 1, 1, 1, 1] },
      { trial: 2, kind: "continuous", visible_ms: [9] },
    ] }],
    idle: [{ memory_measurement: { kind: "physical_footprint" }, records: [
      { trial: 1, implementation: "native", phase: "visible", one_core_percent: 0.1 },
      { trial: 1, implementation: "native", phase: "hidden", one_core_percent: 0.05 },
      { trial: 1, implementation: "legacy", phase: "visible", one_core_percent: 0.2 },
    ] }],
  })
  assert.equal(groups.length, 4)
  assert.deepEqual(groups[0].metrics.visible_ms, { runs: 2, observations: 6, median: 5, min: 1, max: 9 })
  assert.equal(groups[1].metrics.one_core_percent.runs, 1)
  assert.throws(() => summarizeProbes({ idle: [{ records: [{ phase: "visible", cpu_ms: -1 }] }] }), /invalid probe metric/)
})
