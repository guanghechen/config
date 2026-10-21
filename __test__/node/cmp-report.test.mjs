import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"
import { gzipSync } from "node:zlib"

import { collectRuns, measureLoad, renderReport, statistics } from "../../script/benchmark/cmp-report.mjs"

function directory(t) {
  const root = mkdtempSync(join(tmpdir(), "cmp-report-test-"))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  return root
}

function run(root, name, data, metadata = {}, compressed = false) {
  const folder = join(root, name)
  mkdirSync(folder)
  const files = {
    metadata: {
      completion_lua_sha256: "lua-v1",
      native_artifact_sha256: "native-v1",
      benchmark_lua_sha256: "bench-v1",
      cpu: "test",
      ...metadata,
    },
    ...data,
  }
  for (const [phase, value] of Object.entries(files)) {
    const text = JSON.stringify(value)
    writeFileSync(join(folder, `${phase}.json${compressed ? ".gz" : ""}`), compressed ? gzipSync(text) : text)
  }
  return folder
}

function ranking(samples, fingerprint = "order-v1") {
  return {
    construction: [
      { corpus: "identifiers", candidates: 10, sha256: "corpus-v1", normalize: { values: samples }, prepare: { values: samples } },
    ],
    queries: [
      {
        corpus: "identifiers",
        candidates: 10,
        query: "a|b",
        history: "off",
        count: 2,
        fingerprint,
        timings: { rank: { values: samples }, fuzzy_packed: { values: samples, bytes: 16 } },
      },
    ],
  }
}

function loadCase() {
  const resource = (usec, rss) => ({
    process_memory_bytes: rss * 1024,
    lua_heap_bytes: 1024 * 1024,
    usage: {
      utime: { sec: 0, usec },
      stime: { sec: 0, usec: usec / 2 },
      maxrss: rss,
      minflt: 4,
      majflt: 0,
      nvcsw: 3,
      nivcsw: 1,
    },
  })
  return {
    engine: "era",
    scenario: { name: "warm_test", count: 10, interval_ms: 10, seed: "g" },
    plan: ["ge", "get", "ge"].map((query, index) => ({ query, offset_ms: index * 10 })),
    iterations: [
      {
        keys: [2, 12, 22].map((ms) => ({ time_ns: ms * 1e6 })),
        sent: [0, 10, 20].map((ms) => ({ scheduled_ns: ms * 1e6, sent_ns: (ms + 1) * 1e6 })),
        requests: [{ time_ns: -5e6, response_ns: -1e6, delay_ms: 4, query: "g", character: 1 }],
        initial_requests: 1,
        menus: [
          {
            sequence: 1,
            time_ns: 6e6,
            query: "ge",
            buffer_line: "ge",
            visible: true,
            count: 2,
            generation: 1,
            request_sequence: 0,
          },
          {
            sequence: 2,
            time_ns: 16e6,
            query: "ge",
            buffer_line: "get",
            visible: true,
            count: 2,
            generation: 1,
            request_sequence: 0,
          },
        ],
        flushes: [
          {
            time_ns: 7e6,
            line_sequence: 1,
            menu_sequence: 1,
            menu_query: "ge",
            current_query: "ge",
            menu_visible: true,
          },
        ],
        start_ns: 0,
        end_ns: 30e6,
        before: resource(0, 2048),
        after: resource(10000, 4096),
        after_gc: resource(10000, 3072),
        profile: { calls: { rank: 2 }, cost: { rank: 4 } },
        heartbeat_gaps_ms: [2, 5, 18],
        full_gc_ms: 9,
        final_line: "ge",
        final_mode: "i",
        final_visible: true,
        final_menu: { line: "get" },
        unexpected_keys: [],
        errmsg: "",
      },
    ],
  }
}

test("statistics use the mathematical median and nearest-rank p95 without mutating samples", () => {
  const samples = [4, 1, 3, 2]
  assert.deepEqual(statistics(samples), { count: 4, median: 2.5, p95: 4, max: 4, total: 10 })
  assert.deepEqual(samples, [4, 1, 3, 2])
  assert.equal(statistics(Array.from({ length: 20 }, (_, i) => i + 1)).p95, 19)
  assert.equal(statistics([]), null)
  assert.throws(() => statistics([Infinity]), /finite/)
})

test("Lua sampling and Node reporting agree on even and odd sample medians", (t) => {
  const script = join(directory(t), "statistics.lua")
  writeFileSync(
    script,
    `local root = arg[1]
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
local stats = require('__test__.bench.cmp.data').stats
io.stdout:write(vim.json.encode({ stats({1, 2, 3, 4, 5, 6}).median, stats({5, 1, 3}).median }))
`,
  )
  const result = spawnSync("nvim", ["-l", script, new URL("../../", import.meta.url).pathname], { encoding: "utf8" })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(JSON.parse(result.stdout), [3.5, 3])
})

test("partial JSON and gzip runs pool raw samples of the same implementation", (t) => {
  const root = directory(t)
  const first = run(root, "first", { ranking: ranking([1, 3]) })
  const second = run(root, "second", { ranking: ranking([5, 7, 9, 11]) }, {}, true)
  const data = collectRuns([first, second])
  const row = [...data.metrics.values()].find((row) => row.metric === "rank")
  assert.equal(statistics(row.values).median, 6)
  assert.equal(statistics(row.values).count, 6)
  assert.match(renderReport(data), /a\\\|b/)
})

test("pooling rejects duplicate directories, different builds and different sampling conditions", (t) => {
  const root = directory(t)
  const first = run(root, "first", { ranking: ranking([1]) })
  const changed = run(root, "changed", { ranking: ranking([2]) }, { native_artifact_sha256: "native-v2" })
  const differentHost = run(root, "host", { ranking: ranking([2]) }, { cpu: "other" })
  assert.throws(() => collectRuns([first, first]), /same run/)
  assert.throws(() => collectRuns([first, changed]), /different native implementations/)
  assert.throws(() => collectRuns([first, differentHost]), /sampling conditions/)
})

test("before/after comparison reports deliberate ranking changes while rejecting different corpora", (t) => {
  const root = directory(t)
  const before = collectRuns([run(root, "before", { ranking: ranking([1, 2, 3]) })])
  const changed = ranking([3, 4, 5], "order-v2")
  changed.queries[0].count = 3
  const after = collectRuns([run(root, "after", { ranking: changed }, { native_artifact_sha256: "native-v2" })])
  const report = renderReport(before, after)
  assert.match(report, /order-v1 \| order-v2 \| changed/)
  assert.match(report, /returned candidates \| 2 \| 3 \| changed/)
  assert.equal(after.failures.length, 0)
  changed.construction[0].sha256 = "different-corpus"
  const other = collectRuns([run(root, "other", { ranking: changed })])
  assert.throws(() => renderReport(before, other), /comparison workload changed/)
})

test("before/after comparison rejects different hosts and measurement code", (t) => {
  const root = directory(t)
  const before = collectRuns([run(root, "before", { ranking: ranking([1]) })])
  for (const [name, metadata] of [
    ["host", { cpu: "other CPU" }],
    ["harness", { benchmark_lua_sha256: "bench-v2" }],
  ]) {
    const after = collectRuns([run(root, name, { ranking: ranking([10]) }, metadata)])
    assert.throws(() => renderReport(before, after), /comparison sampling conditions differ/)
  }
})

test("load metrics measure offered input and count a menu only when it renders the current query", () => {
  const fixture = loadCase()
  const trace = fixture.iterations[0]
  const measured = measureLoad(fixture, trace)
  assert.deepEqual(measured.dispatch, [1, 1, 1])
  assert.deepEqual(measured.menu, [5])
  assert.deepEqual(measured.menu_count, [1])
  assert.deepEqual(measured.line_flush, [6])
  assert.deepEqual(measured.cpu_per_key, [5])
  assert.deepEqual(measured.after_gc_process_memory_mib, [3])
  assert.deepEqual(measured.max_heartbeat_gap, [18])
  assert.deepEqual(measured.stale_context, [1])
  assert.deepEqual(measured.final_query_lag, [0])
  assert.deepEqual(measured.bad_final, [0])
  assert.deepEqual(measureLoad(fixture, { ...trace, final_mode: "ic" }).bad_final, [0])
  assert.deepEqual(measureLoad(fixture, { ...trace, final_mode: "n" }).bad_final, [1])
})

test("event-query lag is reported separately from correctness and changed load plans are rejected", (t) => {
  const root = directory(t)
  const fixture = loadCase()
  const data = { load: { cases: [fixture], heartbeat_period_ms: 2 } }
  const before = collectRuns([run(root, "before", data)])
  assert.deepEqual(before.failures, [])
  const coverage = [...before.metrics.values()].find((row) => row.metric === "menu coverage")
  assert.deepEqual(coverage.values, [1])
  assert.deepEqual(coverage.denominator, [3])
  fixture.plan[0].offset_ms = 5
  const after = collectRuns([run(root, "after", data)])
  assert.throws(() => renderReport(before, after), /comparison workload changed/)
})

test("load validation rejects queued request positions beyond the current UTF-16 line", () => {
  const fixture = loadCase()
  const trace = fixture.iterations[0]
  trace.requests[0].character = 2
  assert.throws(() => measureLoad(fixture, trace), /request position/)
  trace.requests[0].query = "😀g"
  trace.requests[0].character = 3
  assert.doesNotThrow(() => measureLoad(fixture, trace))
  trace.requests[0].character = 4
  assert.throws(() => measureLoad(fixture, trace), /request position/)
})

test("lost input and undrained responses fail validation", () => {
  const fixture = loadCase()
  const trace = fixture.iterations[0]
  trace.final_line = "lost"
  assert.throws(() => measureLoad(fixture, trace), /lost or reordered/)
  trace.final_line = "ge"
  delete trace.requests[0].response_ns
  assert.throws(() => measureLoad(fixture, trace), /undrained/)
})

test("CLI reports ownership failures with a nonzero exit and does not require all phases", (t) => {
  const root = directory(t)
  const fixture = loadCase()
  fixture.iterations[0].requests[0].cancelled_inflight = true
  const folder = run(root, "load", { load: { cases: [fixture], heartbeat_period_ms: 2 } })
  const result = spawnSync(process.execPath, [new URL("../../script/benchmark/cmp-report.mjs", import.meta.url).pathname, folder], {
    encoding: "utf8",
  })
  assert.equal(result.status, 1)
  assert.match(result.stdout, /Validation failures/)
  assert.match(result.stdout, /cancelled_publication/)
  const broken = run(root, "broken", { ranking: ranking([1]) })
  writeFileSync(join(broken, "ranking.json"), "{")
  assert.throws(() => collectRuns([broken]), SyntaxError)
})
