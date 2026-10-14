// Run with: node __test__/bench/cmp/report.mjs <run-dir> [run-dir...]
import assert from "node:assert/strict"
import { existsSync, readFileSync, realpathSync } from "node:fs"
import { join } from "node:path"
import { gunzipSync } from "node:zlib"

const phases = ["ranking", "matching", "sources", "ui", "memory", "load"]
const sum = (values) => values.reduce((total, value) => total + value, 0)
const version = (metadata) => metadata.native_sha256 ?? metadata.libraries?.era?.sha256

export function statistics(values) {
  assert(values.every(Number.isFinite), "samples must be finite numbers")
  if (values.length === 0) return null
  const ordered = [...values].sort((a, b) => a - b)
  const middle = Math.floor(ordered.length / 2)
  return {
    count: ordered.length,
    median: ordered.length % 2 ? ordered[middle] : (ordered[middle - 1] + ordered[middle]) / 2,
    p95: ordered[Math.ceil(ordered.length * 0.95) - 1],
    max: ordered.at(-1),
    total: sum(values),
  }
}

function read(folder, phase) {
  const path = join(folder, `${phase}.json`)
  if (existsSync(path)) return JSON.parse(readFileSync(path, "utf8"))
  if (existsSync(`${path}.gz`)) return JSON.parse(gunzipSync(readFileSync(`${path}.gz`)).toString("utf8"))
  return null
}

// Blink ranks the live line; its render context can describe an older input.
function matchingQuery(engine, menu) {
  return engine === "blink" ? menu.buffer_line : menu.query
}

export function measureLoad(testCase, trace) {
  const { plan, engine, scenario } = testCase
  const size = plan.length
  assert(size > 0, "empty input plan")
  assert.equal(trace.keys.length, size, "input trace length differs")
  assert.equal(trace.sent.length, size, "sent input length differs")
  assert.equal(trace.unexpected_keys.length, 0, "unexpected input")
  assert.equal(trace.errmsg, "", "editor error")
  assert.equal(trace.final_line, plan.at(-1).query, "input text was lost or reordered")
  assert(
    trace.requests.every((request) => request.response_ns !== undefined),
    "undrained server responses",
  )
  // The load fixture uses UTF-16 clients and captures the actual line when each request is submitted.
  assert(
    trace.requests.every(
      (request) =>
        Number.isInteger(request.character) && request.character >= 0 && request.character <= request.query.length,
    ),
    "completion request position is outside the current line",
  )
  const result = { producer_jitter: [], dispatch: [], scheduled_dispatch: [] }
  for (let i = 0; i < size; i++) {
    const sent = trace.sent[i]
    result.producer_jitter.push((sent.sent_ns - sent.scheduled_ns) / 1e6)
    result.dispatch.push((trace.keys[i].time_ns - sent.sent_ns) / 1e6)
    result.scheduled_dispatch.push((trace.keys[i].time_ns - sent.scheduled_ns) / 1e6)
  }
  const events = Object.fromEntries(["menu", "fresh_menu", "line_flush", "menu_flush"].map((name) => [name, new Map()]))
  const visible = trace.menus.filter((menu) => menu.visible && menu.count > 0 && menu.sequence)
  let generation = 0
  let staleContext = 0,
    cancelledPublication = 0,
    regression = 0,
    afterEscape = 0
  for (const menu of visible) {
    const sequence = menu.sequence
    assert.equal(menu.buffer_line, plan[sequence - 1].query, "unexpected edit inside a render")
    staleContext += Number(menu.query !== menu.buffer_line)
    regression += Number(menu.generation < generation)
    generation = Math.max(generation, menu.generation)
    afterEscape += Number(menu.time_ns > (trace.escape_ns ?? Infinity))
    const request = trace.requests[menu.generation - 1]
    assert(request, "menu references an unknown request")
    cancelledPublication += Number(Boolean(request.cancelled_inflight && request.response_ns <= menu.time_ns))
    if (matchingQuery(engine, menu) === plan[sequence - 1].query) {
      if (!events.menu.has(sequence)) events.menu.set(sequence, menu.time_ns)
      if (menu.request_sequence === sequence && !events.fresh_menu.has(sequence)) {
        events.fresh_menu.set(sequence, menu.time_ns)
      }
    }
  }
  let oldContextFlush = 0,
    currentMenuFlush = 0
  for (const flush of trace.flushes) {
    if (flush.line_sequence && !events.line_flush.has(flush.line_sequence)) {
      events.line_flush.set(flush.line_sequence, flush.time_ns)
    }
    const sequence = flush.menu_sequence
    const query = sequence && engine === "blink" ? plan[sequence - 1].query : flush.menu_query
    if (sequence && flush.menu_visible) {
      oldContextFlush += Number(query !== flush.current_query)
      if (query === plan[sequence - 1].query) {
        if (!events.menu_flush.has(sequence)) events.menu_flush.set(sequence, flush.time_ns)
        currentMenuFlush += Number(query === flush.current_query)
      }
    }
  }
  for (const [name, times] of Object.entries(events)) {
    result[name] = [...times].map(([sequence, time]) => (time - trace.sent[sequence - 1].sent_ns) / 1e6)
    result[`${name}_count`] = [times.size]
  }
  const finalMenu = trace.final_menu ?? {}
  const expectedMode = scenario.hide ? "n" : "i"
  const correctMode = expectedMode === "i" ? trace.final_mode[0] === "i" : trace.final_mode === "n"
  const correctFinal =
    correctMode && (engine === "none" || trace.final_visible === !scenario.hide)
  const finalQuery = visible.length ? matchingQuery(engine, visible.at(-1)) : finalMenu.line
  const before = trace.before.usage,
    after = trace.after.usage
  const seconds = (time) => time.sec + time.usec / 1e6
  const cpu = (seconds(after.utime) - seconds(before.utime) + seconds(after.stime) - seconds(before.stime)) * 1000
  const wall = (trace.end_ns - trace.start_ns) / 1e6
  const current = visible.filter((menu) => matchingQuery(engine, menu) === menu.buffer_line)
  const calls = trace.profile.calls ?? {},
    cost = trace.profile.cost ?? {}
  const requests = trace.requests.slice(trace.initial_requests)
  const counters = {
    bad_final: Number(!correctFinal),
    final_context_lag: Number(trace.final_visible && finalMenu.line !== trace.final_line),
    final_query_lag: Number(trace.final_visible && finalQuery !== trace.final_line),
    stale_context: staleContext,
    old_context_flush: oldContextFlush,
    current_menu_flush: currentMenuFlush,
    cancelled_publication: cancelledPublication,
    generation_regression: regression,
    after_escape: afterEscape,
    cpu_ms: cpu,
    cpu_per_key: cpu / size,
    cpu_percent: (cpu / wall) * 100,
    wall_ms: wall,
    max_heartbeat_gap: Math.max(...trace.heartbeat_gaps_ms),
    heartbeat_over_16ms: trace.heartbeat_gaps_ms.filter((value) => value > 1000 / 60).length,
    final_drain: (trace.keys.at(-1).time_ns - trace.sent.at(-1).scheduled_ns) / 1e6,
    renders: trace.menus.length,
    visible_menu_calls: visible.length,
    prepare_calls: calls.prepare ?? 0,
    prepare_ms: cost.prepare ?? 0,
    rank_calls: calls.rank ?? calls.rank_including_prepare ?? 0,
    rank_ms: cost.rank ?? cost.rank_including_prepare ?? 0,
    key_count: size,
    full_gc_ms: trace.full_gc_ms,
    lifetime_maxrss_mib: after.maxrss / 1024,
    requests: requests.length,
    cancel_inflight: requests.filter((request) => request.cancelled_inflight).length,
    cancel_completed: trace.requests.filter((request) => request.cancel_ns !== undefined && !request.cancelled_inflight)
      .length,
    late_after_escape: requests.filter((request) => request.response_ns > (trace.escape_ns ?? Infinity)).length,
  }
  for (const [name, value] of Object.entries(counters)) result[name] = [value]
  result.heartbeat_gap = trace.heartbeat_gaps_ms
  result.first_current_menu = current.length ? [(current[0].time_ns - trace.sent[0].sent_ns) / 1e6] : []
  for (const state of ["before", "after", "after_gc"]) {
    for (const kind of ["rss", "lua"]) result[`${state}_${kind}_mib`] = [trace[state][`${kind}_kib`] / 1024]
  }
  for (const name of ["minflt", "majflt", "nvcsw", "nivcsw"]) result[name] = [after[name] - before[name]]
  result.response_timer_slip = requests.map(
    (request) => (request.response_ns - request.time_ns) / 1e6 - request.delay_ms,
  )
  const boundaries = requests
    .flatMap((request) => [
      [request.time_ns, 1],
      [request.response_ns, -1],
    ])
    .sort((a, b) => a[0] - b[0] || a[1] - b[1])
  let inflight = 0,
    peak = 0
  for (const [, delta] of boundaries) {
    inflight += delta
    peak = Math.max(peak, inflight)
  }
  result.peak_inflight = [peak]
  return result
}

const loadTimings = [
  "producer_jitter",
  "dispatch",
  "scheduled_dispatch",
  "line_flush",
  "menu",
  "menu_flush",
  "first_current_menu",
  "fresh_menu",
  "final_drain",
  "response_timer_slip",
]
const loadResources = [
  "cpu_ms",
  "cpu_per_key",
  "cpu_percent",
  "max_heartbeat_gap",
  "heartbeat_gap",
  "wall_ms",
  "prepare_calls",
  "prepare_ms",
  "rank_calls",
  "rank_ms",
  "visible_menu_calls",
  "peak_inflight",
  "full_gc_ms",
  "before_rss_mib",
  "after_rss_mib",
  "after_gc_rss_mib",
  "after_gc_lua_mib",
  "before_lua_mib",
  "after_lua_mib",
  "lifetime_maxrss_mib",
]
const loadTotals = [
  "key_count",
  "requests",
  "cancel_inflight",
  "cancel_completed",
  "late_after_escape",
  "stale_context",
  "old_context_flush",
  "cancelled_publication",
  "generation_regression",
  "after_escape",
  "bad_final",
  "final_context_lag",
  "final_query_lag",
  "current_menu_flush",
  "heartbeat_over_16ms",
  "renders",
  "minflt",
  "majflt",
  "nvcsw",
  "nivcsw",
]
const correctness = ["cancelled_publication", "generation_regression", "after_escape", "bad_final"]

export function collectRuns(folders) {
  assert(folders.length > 0, "provide at least one run directory")
  assert.equal(
    new Set(folders.map((folder) => realpathSync(folder))).size,
    folders.length,
    "the same run was supplied twice",
  )
  const metrics = new Map(),
    results = new Map(),
    builds = new Map(),
    inputs = []
  const failures = []
  for (const folder of folders) {
    const metadata = read(folder, "metadata")
    assert(metadata, `${folder}: metadata.json is missing`)
    if (folders.length > 1) {
      assert(
        metadata.completion_lua_sha256 && version(metadata),
        `${folder}: source/binary identity is required for pooling`,
      )
    }
    for (const [name, hash] of Object.entries({
      lua: metadata.completion_lua_sha256,
      era: version(metadata),
      blink: metadata.libraries?.blink?.sha256,
      blink_lua: metadata.blink_lua_sha256,
    })) {
      if (hash === undefined) continue
      assert(
        !builds.has(name) || builds.get(name) === hash,
        `cannot pool different ${name} implementations; use --before/--after`,
      )
      builds.set(name, hash)
    }
    inputs.push({ folder, metadata })
    const sampling = {
      benchmark: metadata.benchmark_lua_sha256,
      runtime: metadata.runtime_sha256,
      cpu: metadata.cpu,
      system: metadata.system,
      neovim: metadata.neovim,
      luajit: metadata.luajit,
      parallelism: metadata.parallelism,
      warmup: metadata.warmup,
      gc: metadata.gc,
      load_gc: metadata.load_gc,
    }
    function add(section, scenario, engine, metric, values, unit = "ms", workload = {}, denominator = []) {
      if (folders.length > 1 && (engine === "paired" || engine.startsWith("blink"))) {
        assert(
          metadata.blink_lua_sha256 && metadata.libraries?.blink?.sha256,
          `${folder}: Blink Lua/native identity is required for pooling`,
        )
      }
      assert(Array.isArray(values), `${section}/${metric}: raw samples are missing`)
      const key = JSON.stringify([section, scenario, engine, metric])
      let row = metrics.get(key)
      if (row) {
        assert.deepEqual(row.sampling, sampling, `${scenario}: cannot pool different sampling conditions`)
        assert.deepEqual(row.workload, workload, `${scenario}: cannot pool different workloads`)
      } else {
        row = { section, scenario, engine, metric, unit, workload, sampling, values: [], denominator: [] }
        metrics.set(key, row)
      }
      row.values.push(...values)
      row.denominator.push(...denominator)
    }
    function outcome(scenario, metric, value) {
      const key = JSON.stringify([scenario, metric])
      if (!results.has(key)) results.set(key, { scenario, metric, values: new Set() })
      results.get(key).values.add(String(value))
    }
    let found = false
    for (const phase of phases) {
      const data = read(folder, phase)
      if (!data) continue
      found = true
      if (phase === "ranking" || phase === "matching") {
        for (const row of data.construction) {
          const scenario = `${row.corpus}/${row.candidates}`
          const timings = phase === "ranking" ? { normalize: row.normalize, prepare: row.prepare } : row.timings
          for (const [metric, values] of Object.entries(timings)) {
            add(
              `${phase} construction`,
              scenario,
              phase === "ranking" ? "era" : "paired",
              metric,
              values.samples,
              "ms",
              { corpus: row.sha256 },
            )
          }
        }
        for (const row of data.queries) {
          const scenario = `${row.corpus}/${row.candidates}/${JSON.stringify(row.query)}/${row.history ?? "off"}`
          for (const [metric, values] of Object.entries(row.timings)) {
            const corpus = data.construction.find(
              (entry) => entry.corpus === row.corpus && entry.candidates === row.candidates,
            )
            add(phase, scenario, phase === "ranking" ? "era" : "paired", metric, values.samples, "ms", {
              corpus: corpus?.sha256,
            })
          }
          if (phase === "ranking") {
            outcome(scenario, "returned candidates", row.count)
            outcome(scenario, "ordered ID/score fingerprint", row.fingerprint)
            if (row.timings.fuzzy_packed.bytes !== undefined) {
              outcome(scenario, "full-match packed bytes", row.timings.fuzzy_packed.bytes)
            }
          } else {
            outcome(
              scenario,
              "matching sets (Era/Blink/intersection)",
              `${row.agreement.era_count}/${row.agreement.blink_count}/${row.agreement.intersection}`,
            )
            outcome(scenario, "Era top 10", JSON.stringify(row.era_top10))
            outcome(scenario, "Blink top 10", JSON.stringify(row.blink_top10))
          }
        }
        for (const row of data.quality ?? []) {
          for (const engine of ["era", "blink", "blink_default_typos"]) {
            if (row[engine] !== undefined)
              outcome(`quality/${JSON.stringify(row.query)}`, engine, JSON.stringify(row[engine]))
          }
        }
      } else if (phase === "sources") {
        const sources = []
        for (const row of data.buffers) {
          for (const state of ["hot", "changedtick"])
            sources.push([`buffer/${row.words} words/${row.bytes} bytes/${state}`, row[state]])
        }
        for (const row of data.paths) sources.push([`path/${row.entries}`, row.timings])
        sources.push(["snippets", data.snippets])
        for (const [scenario, engines] of sources) {
          for (const [engine, timings] of Object.entries(engines)) {
            for (const metric of ["latency_ms", "synchronous_ms"])
              add("sources", scenario, engine, metric, timings[metric].samples)
            outcome(`sources/${scenario}`, `${engine} candidates`, timings.count)
          }
        }
      } else if (phase === "ui") {
        for (const row of data.cases) {
          for (const sample of row.samples) {
            for (const step of sample.steps) {
              const scenario = `${row.scenario}/${JSON.stringify(step.query)}`
              for (const [metric, value] of Object.entries({
                first_menu_ms: step.first_menu_ms,
                flush_ms: step.flush_ms,
                settled_menu_ms: step.last_menu_ms ?? step.first_menu_ms,
              })) {
                add("sequential UI", scenario, row.engine, metric, [value])
              }
            }
            for (const metric of ["select_ms", "accept_ms"])
              add("sequential UI", row.scenario, row.engine, metric, [sample[metric]])
          }
        }
      } else if (phase === "memory") {
        for (const row of data.cases) {
          for (const [metric, values] of Object.entries(row.summary)) {
            const kib = metric.endsWith("_kib")
            add(
              "standalone fuzzy memory",
              String(row.candidates),
              row.engine,
              metric.replace("_kib", "_mib"),
              values.samples.map((value) => (kib ? value / 1024 : value)),
              kib ? "MiB" : "ms",
            )
          }
        }
      } else if (phase === "load") {
        const history = metadata.load_history
          ? `${metadata.load_history.state}/${metadata.load_history.entries}`
          : (metadata.frecency ?? "unspecified history")
        for (const row of data.cases) {
          const scenario = `${row.scenario.name}/${history}`
          const workload = { scenario: row.scenario, plan: row.plan, heartbeat: data.heartbeat_period_ms }
          for (const sample of row.samples) {
            const measured = measureLoad(row, sample)
            for (const metric of loadTimings)
              add("load latency", scenario, row.engine, metric, measured[metric], "ms", workload)
            for (const metric of loadResources) {
              const unit = metric.endsWith("_mib")
                ? "MiB"
                : metric.endsWith("_calls") || metric === "peak_inflight"
                  ? "count"
                  : metric === "cpu_percent"
                    ? "%"
                    : metric === "cpu_per_key"
                      ? "ms/key"
                      : "ms"
              add("load resources", scenario, row.engine, metric, measured[metric], unit, workload)
            }
            for (const metric of loadTotals)
              add("load events", scenario, row.engine, metric, measured[metric], "total", workload)
            for (const metric of ["menu", "menu_flush", "fresh_menu"]) {
              add(
                "load publication",
                scenario,
                row.engine,
                `${metric} coverage`,
                measured[`${metric}_count`],
                "rate",
                workload,
                measured.key_count,
              )
            }
            for (const [metric, budget] of [
              ["dispatch", 1000 / 60],
              ["dispatch", 50],
              ["menu", 1000 / 60],
              ["menu", 1000 / 30],
            ]) {
              add(
                "load budgets",
                scenario,
                row.engine,
                `${metric} > ${budget.toFixed(2)} ms`,
                [measured[metric].filter((value) => value > budget).length],
                "rate",
                workload,
                [measured[metric].length],
              )
            }
            for (const metric of correctness) {
              if (sum(measured[metric])) failures.push(`${scenario}/${row.engine}: ${metric}`)
            }
            if (/^(warm|dense)_/.test(row.scenario.name) && sum(measured.prepare_calls))
              failures.push(`${scenario}/${row.engine}: warm snapshot rebuilt`)
          }
        }
      }
    }
    assert(found, `${folder}: no completed benchmark phases found`)
  }
  assert(metrics.size > 0, "no benchmark samples found")
  return { inputs, metrics, results, failures }
}

function cell(row) {
  const stats = statistics(row.values)
  if (!stats) return "—"
  if (row.unit === "total") return String(stats.total)
  if (row.unit === "rate")
    return sum(row.denominator) ? `${((stats.total / sum(row.denominator)) * 100).toFixed(1)}%` : "—"
  return `${stats.median.toFixed(2)} / ${stats.p95.toFixed(2)}`
}

function table(title, headings, rows) {
  const escape = (value) => String(value).replaceAll("|", "\\|").replaceAll("\n", "\\n")
  return (
    `\n## ${title}\n\n` +
    [headings, headings.map(() => "---"), ...rows].map((row) => `| ${row.map(escape).join(" | ")} |`).join("\n") +
    "\n"
  )
}

export function renderReport(before, after) {
  if (after) {
    assert.deepEqual([...before.metrics.keys()].sort(), [...after.metrics.keys()].sort(), "comparison workloads differ")
    for (const [key, row] of before.metrics) {
      assert.deepEqual(row.workload, after.metrics.get(key).workload, `${row.scenario}: comparison workload changed`)
      assert.deepEqual(
        row.sampling,
        after.metrics.get(key).sampling,
        `${row.scenario}: comparison sampling conditions differ`,
      )
    }
  }
  let output =
    "# Completion benchmark\n\nRaw samples determine median and nearest-rank p95. No timing threshold decides pass/fail.\n"
  output +=
    "Load key percentiles pool correlated keys; resource samples describe bursts. CPU includes the editor and observer.\n"
  output +=
    "RSS includes prebuilt server payloads. Explicit GC is outside the timed burst. UI flush excludes the compositor.\n"
  output +=
    "Publication coverage and final_query_lag describe menu events, not candidate correctness. Rank scores may change with history age.\n"
  output += "Cells show median / p95 [N], event totals, or weighted rates."
  if (after) output += " Arrows mean before → after; percentages in parentheses are median changes."
  output += "\n"
  output += table(
    "Inputs",
    ["Side", "Directory", "Era Lua SHA", "Era native SHA", "Blink Lua SHA", "Blink native SHA"],
    [before, after]
      .filter(Boolean)
      .flatMap((side, index) =>
        side.inputs.map(({ folder, metadata }) => [
          after ? (index ? "after" : "before") : "run",
          folder,
          metadata.completion_lua_sha256 ?? "unknown",
          version(metadata) ?? "unknown",
          metadata.blink_lua_sha256 ?? (metadata.libraries?.blink ? "unknown" : "—"),
          metadata.libraries?.blink?.sha256 ?? "—",
        ]),
      ),
  )
  const sections = new Map()
  for (const [key, row] of [...before.metrics].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) {
    if (!sections.has(row.section)) sections.set(row.section, { columns: new Set(), cases: new Map() })
    const section = sections.get(row.section)
    const column = `${row.metric} (${row.unit})`
    section.columns.add(column)
    const caseKey = JSON.stringify([row.scenario, row.engine])
    if (!section.cases.has(caseKey))
      section.cases.set(caseKey, { scenario: row.scenario, engine: row.engine, cells: new Map() })
    const format = (entry) => cell(entry) + (["total", "rate"].includes(entry.unit) ? "" : ` [${entry.values.length}]`)
    const target = after?.metrics.get(key)
    let value = format(row)
    if (target) {
      const left = statistics(row.values),
        right = statistics(target.values)
      const change =
        left && right && left.median !== 0 && !["total", "rate"].includes(row.unit)
          ? `${((right.median / left.median - 1) * 100).toFixed(1)}%`
          : null
      value += ` → ${format(target)}` + (change === null ? "" : ` (${change})`)
    }
    section.cases.get(caseKey).cells.set(column, value)
  }
  for (const [name, section] of sections) {
    const columns = [...section.columns]
    output += table(
      name,
      ["Scenario", "Engine", ...columns],
      [...section.cases.values()].map((row) => [
        row.scenario,
        row.engine,
        ...columns.map((column) => row.cells.get(column) ?? "—"),
      ]),
    )
  }
  const outcomes = []
  const resultKeys = new Set([...before.results.keys(), ...(after?.results.keys() ?? [])])
  for (const key of [...resultKeys].sort()) {
    const left = before.results.get(key),
      right = after?.results.get(key)
    const row = left ?? right
    const values = (entry) => (entry ? [...entry.values].sort().join("; ") : "—")
    outcomes.push([
      row.scenario,
      row.metric,
      values(left),
      ...(after ? [values(right), values(left) === values(right) ? "same" : "changed"] : []),
    ])
  }
  if (outcomes.length)
    output += table(
      "Result differences",
      ["Scenario", "Metric", after ? "Before" : "Observed", ...(after ? ["After", "Agreement"] : [])],
      outcomes,
    )
  const failures = [...before.failures, ...(after?.failures ?? [])]
  if (failures.length)
    output += `\nValidation failures:\n\n${[...new Set(failures)].map((failure) => `- ${failure}`).join("\n")}\n`
  else if (sections.has("load events"))
    output += "\nInput, request ownership and warm-cache checks passed for the supplied load traces.\n"
  return output
}

function main(args) {
  if (args.length === 1 && args[0] === "--help") {
    process.stdout.write(
      "node __test__/bench/cmp/report.mjs <run-dir...>\nnode __test__/bench/cmp/report.mjs --before <run-dir...> --after <run-dir...>\n",
    )
    return
  }
  let before, after
  if (args[0] === "--before") {
    const separator = args.indexOf("--after")
    assert(separator > 1 && separator < args.length - 1, "use --before <run-dir...> --after <run-dir...>")
    before = collectRuns(args.slice(1, separator))
    after = collectRuns(args.slice(separator + 1))
  } else {
    assert(
      args.length > 0 && args.every((arg) => !arg.startsWith("--")),
      "use <run-dir...> or --before <run-dir...> --after <run-dir...>",
    )
    before = collectRuns(args)
  }
  process.stdout.write(renderReport(before, after))
  if (before.failures.length || after?.failures.length) process.exitCode = 1
}

if (import.meta.main) main(process.argv.slice(2))
