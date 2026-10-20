import { strict as assert } from "node:assert"
import { mkdtempSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { test } from "node:test"

import { canonical, mulberry32, sequencesFor, synthesizePaths, wordsOf } from "../../script/benchmark/fuzzy-corpus.mjs"
import { analyze, distribution, slowProcess, summarizeE2e, summarizeFfi, summarizeRust } from "../../script/benchmark/fuzzy-report.mjs"
import { median, percentile, variation } from "../../script/benchmark/stats.mjs"

test("the PRNG repeats its sequence for a seed", () => {
  const first = mulberry32(42), second = mulberry32(42)
  const values = Array.from({ length: 5 }, () => first())
  assert.deepEqual(values, Array.from({ length: 5 }, () => second()))
  assert.ok(values.every((value) => value >= 0 && value < 1))
  assert.notDeepEqual(values, Array.from({ length: 5 }, mulberry32(43)))
})

test("canonical order sorts UTF-8 bytes and drops duplicates, blanks and control separators", () => {
  assert.deepEqual(canonical(["b", "a", "Z", "é", "a", "", "x\ty", "e"]), ["Z", "a", "b", "e", "é"])
})

test("words split separators and camel case", () => {
  assert.deepEqual(wordsOf("result_tree.lua"), ["result", "tree", "lua"])
  assert.deepEqual(wordsOf("bufNrGetLines"), ["buf", "Nr", "Get", "Lines"])
})

test("synthetic paths are unique and deterministic", () => {
  const pools = { dirs: ["lua", "era", "view"], stems: ["init", "tree", "util"], extensions: [".lua", ".md"] }
  const first = synthesizePaths(200, pools, mulberry32(7))
  assert.equal(new Set(first).size, 200)
  assert.deepEqual(first, synthesizePaths(200, pools, mulberry32(7)))
})

test("typing sequences grow one character at a time and are deterministic", () => {
  const items = canonical(["lua/era/view/result_tree.lua", "lua/stl/c/frecency.lua", "spec/design/README.md"])
  const sequences = sequencesFor({ kind: "path" }, items, mulberry32(1))
  assert.deepEqual(sequences, sequencesFor({ kind: "path" }, items, mulberry32(1)))
  for (const sequence of sequences) {
    assert.equal(sequence.steps.at(-1), sequence.query)
    sequence.steps.forEach((step, index) => assert.equal([...step].length, index + 1))
  }
  assert.ok(sequences.some((sequence) => sequence.kind === "nomatch"))
  assert.ok(sequences.some((sequence) => sequence.kind === "extended"))
})

test("percentiles use the nearest rank and medians average the middle pair", () => {
  const values = Array.from({ length: 20 }, (_, index) => index + 1)
  assert.equal(percentile(values, 0.95), 19)
  assert.equal(percentile(values, 0.5), 10)
  assert.equal(median([4, 1, 3, 2]), 2.5)
  assert.equal(median([]), undefined)
})

test("a process p95 needs at least 20 processes", () => {
  assert.equal(distribution([1, 2, 3], [1, 2, 3]).process_p95, undefined)
  assert.equal(distribution([1], Array.from({ length: 20 }, (_, index) => index)).process_p95, 18)
  assert.equal(variation([2, 2, 2]), 0)
  assert.equal(variation([1]), undefined)
})

test("slow processes are those whose calibration exceeds 1.3 times the median", () => {
  const records = [10, 11, 12, 30].map((calibration_ms) => ({ calibration_ms }))
  const slow = slowProcess(records)
  assert.deepEqual(records.map(slow), [false, false, false, true])
  assert.equal(slowProcess([{}])({}), false)
})

test("L1 summaries reduce each query across processes before summarizing", () => {
  const row = (sequence, step, length, ns) => [sequence, step, length, "stem", ns, 3]
  const records = [1, 2, 3].map((run) => ({
    level: "rust", corpus: "repo", items: 10, probe: "fuzzy", threads: 1, build_ms: 1, run,
    queries: [row(1, 1, 1, 1e6 * run), row(1, 2, 2, 2e6), row(2, 1, 7, 9e6)],
  }))
  const [group] = summarizeRust(records)
  assert.equal(group.runs, 3)
  assert.equal(group.overall.n, 3)
  assert.equal(group.lengths["1"].p50, 2)
  assert.equal(group.lengths["7+"].max, 9)
  assert.equal(group.matched_median, 3)
})

test("L2 summaries keep stage and allocation distributions", () => {
  const records = [{
    level: "ffi", corpus: "labels", items: 5, pipeline: "old_list", stages: ["lines", "search"], cold: { total_ms: 4 },
    queries: [[1, 1, 1, "prefix", 3e6, 2, 10, [1e6, 2e6]], [1, 2, 2, "prefix", 1e6, 1, 4, [0.5e6, 0.5e6]]],
  }]
  const [group] = summarizeFfi(records)
  assert.equal(group.stages.search.max, 2)
  assert.equal(group.allocated_kib.max, 10)
  assert.equal(group.cold_ms, 4)
})

test("L3 summaries pool keystrokes and count superseded, unchanged and coalesced ones", () => {
  const key = (fields) => ({ coalesced: false, superseded: false, unchanged: false, ...fields })
  const records = [{
    level: "e2e", case: "list_labels", implementation: "current", scenario: "list", mode: "list", corpus: "labels", items: 5, pace_ms: 120,
    open: { visible_ms: 50 }, memory: { process_memory_bytes: 1048576, errors: [] },
    sequences: [{ settled: true, cpu_ms: 10 }, { settled: false, cpu_ms: 20 }],
    keystrokes: [
      key({ fire_to_visible_ms: 10, key_to_visible_ms: 80, match_ms: 5 }),
      key({ fire_to_visible_ms: 30, key_to_visible_ms: 90, match_ms: 7, unchanged: true }),
      key({ coalesced: true }),
      key({ match_ms: 70, superseded: true }),
    ],
  }]
  const [group] = summarizeE2e(records)
  assert.equal(group.metrics.fire_to_visible_ms.n, 2)
  assert.equal(group.metrics.match_ms.n, 3)
  assert.deepEqual([group.coalesced, group.superseded, group.unchanged, group.unsettled], [1, 1, 1, 1])
  assert.equal(group.memory_mib, 1)
})

test("analyze writes a report from a result directory", () => {
  const directory = mkdtempSync(join(tmpdir(), "fuzzy-report-"))
  writeFileSync(join(directory, "metadata.json"), JSON.stringify({ status: "complete", started_at: "now", host: {}, nvim: ["NVIM"] }))
  writeFileSync(join(directory, "results.jsonl"), `${JSON.stringify({
    level: "rust", corpus: "repo", items: 10, probe: "search_in_lines", threads: 1, build_ms: 0, queries: [[1, 1, 1, "stem", 1e6, 1]],
  })}\n`)
  const summary = analyze(directory)
  assert.equal(summary.rust.length, 1)
})
