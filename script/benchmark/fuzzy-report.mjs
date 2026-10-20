// Summaries and the Markdown report for script/benchmark/fuzzy.mjs results.
import { existsSync, readFileSync, writeFileSync } from "node:fs"
import { join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { median, percentile, variation } from "./stats.mjs"

/** Distribution of `values`; `processes` are per-process medians, which alone may report a process p95.
 *  `process_cv` measures run-to-run noise. */
export function distribution(values, processes = []) {
  return {
    n: values.length,
    p50: median(values),
    p95: percentile(values, 0.95),
    max: values.length ? Math.max(...values) : undefined,
    processes: processes.length,
    process_median: median(processes),
    ...(processes.length >= 20 ? { process_p95: percentile(processes, 0.95) } : {}),
    process_cv: variation(processes),
  }
}

export const LENGTH_BUCKETS = [
  ["1", (length) => length === 1], ["2", (length) => length === 2], ["3", (length) => length === 3],
  ["4", (length) => length === 4], ["5-6", (length) => length >= 5 && length <= 6], ["7+", (length) => length >= 7],
]

/** Processes whose calibration loop ran over 1.3 times the level's median likely got a slower core. */
export function slowProcess(records) {
  const reference = median(records.map((record) => record.calibration_ms).filter(Number.isFinite))
  return (record) => reference !== undefined && Number.isFinite(record.calibration_ms) && record.calibration_ms > reference * 1.3
}

const calibration = (group, slow) => ({
  calibration_ms: median(group.map((record) => record.calibration_ms).filter(Number.isFinite)),
  slow_processes: group.filter(slow).length,
})

const groupBy = (records, key) => {
  const groups = new Map()
  for (const record of records) {
    const name = JSON.stringify(key(record))
    if (!groups.has(name)) groups.set(name, [])
    groups.get(name).push(record)
  }
  return groups
}

/**
 * L1 and L2 records carry one median per query and process. Per-query values are first reduced across
 * processes, then summarized over queries; per-process p50/p95 give the run-to-run spread.
 */
function summarizeQueries(records, column, length, extra = () => ({})) {
  const perQuery = new Map(), processes = { p50: [], p95: [] }
  for (const record of records) {
    const values = []
    for (const row of record.queries) {
      const key = `${row[0]}:${row[1]}`
      if (!perQuery.has(key)) perQuery.set(key, { length: row[length], kind: row[3], values: [], row })
      perQuery.get(key).values.push(row[column])
      values.push(row[column])
    }
    processes.p50.push(median(values))
    processes.p95.push(percentile(values, 0.95))
  }
  const queries = [...perQuery.values()].map((query) => ({ ...query, value: median(query.values) }))
  const ms = (values) => values.map((value) => value / 1e6)
  const overall = distribution(ms(queries.map((query) => query.value)), ms(processes.p50))
  overall.process_p95_median = median(ms(processes.p95))
  const lengths = Object.fromEntries(LENGTH_BUCKETS.map(([name, test]) => [name, distribution(ms(queries.filter((query) => test(query.length)).map((query) => query.value)))]))
  const kinds = Object.fromEntries([...new Set(queries.map((query) => query.kind))].map((kind) => [kind, distribution(ms(queries.filter((query) => query.kind === kind).map((query) => query.value)))]))
  return { overall, lengths, kinds, ...extra(queries) }
}

export function summarizeRust(records) {
  const slow = slowProcess(records)
  return [...groupBy(records, (record) => [record.corpus, record.probe, record.threads ?? 1])].map(([, group]) => ({
    corpus: group[0].corpus, items: group[0].items, probe: group[0].probe, threads: group[0].threads ?? 1, runs: group.length, ...calibration(group, slow),
    build_ms: median(group.map((record) => record.build_ms)),
    ...summarizeQueries(group, 4, 2, (queries) => ({ matched_median: median(queries.map((query) => query.row[5])) })),
  }))
}

export function summarizeFfi(records) {
  const slow = slowProcess(records)
  return [...groupBy(records, (record) => [record.corpus, record.pipeline])].map(([, group]) => {
    const summary = summarizeQueries(group, 4, 2)
    const stages = Object.fromEntries(group[0].stages.map((stage, index) => [stage, distribution(group.flatMap((record) => record.queries.map((row) => row[7][index] / 1e6)))]))
    return {
      corpus: group[0].corpus, items: group[0].items, pipeline: group[0].pipeline, runs: group.length, ...calibration(group, slow), ...summary, stages,
      allocated_kib: distribution(group.flatMap((record) => record.queries.map((row) => row[6]))),
      cold_ms: median(group.map((record) => record.cold.total_ms)),
    }
  })
}

export const E2E_METRICS = ["key_to_visible_ms", "fire_to_visible_ms", "match_ms", "display_ms", "fire_to_published_ms", "input_ms"]

export function summarizeE2e(records) {
  const slow = slowProcess(records)
  return [...groupBy(records, (record) => [record.case, record.implementation])].map(([, group]) => {
    const first = group[0], metrics = {}
    for (const name of E2E_METRICS) {
      const pooled = [], processes = []
      for (const record of group) {
        const values = record.keystrokes.filter((key) => !key.coalesced && key[name] != null).map((key) => key[name])
        pooled.push(...values)
        if (values.length) processes.push(median(values))
      }
      metrics[name] = distribution(pooled, processes)
    }
    const keystrokes = group.flatMap((record) => record.keystrokes), sequences = group.flatMap((record) => record.sequences)
    return {
      case: first.case, implementation: first.implementation, scenario: first.scenario, mode: first.mode, corpus: first.corpus,
      items: first.items, pace_ms: first.pace_ms, runs: group.length, ...calibration(group, slow), metrics,
      keystrokes: keystrokes.length,
      coalesced: keystrokes.filter((key) => key.coalesced).length,
      superseded: keystrokes.filter((key) => key.superseded).length,
      unchanged: keystrokes.filter((key) => key.unchanged).length,
      unsettled: sequences.filter((sequence) => !sequence.settled).length,
      open_visible_ms: median(group.map((record) => record.open.visible_ms)),
      sequence_cpu_ms: median(sequences.map((sequence) => sequence.cpu_ms)),
      memory_mib: median(group.map((record) => record.memory.process_memory_bytes / 1048576)),
      errors: [...new Set(group.flatMap((record) => record.memory.errors ?? []))],
    }
  })
}

/** Budgets from spec/design/feat/yoz/fuzzy.md; `applies` limits each to the candidate it constrains. L3 follows the
 * Treeview filter contract up to 50k candidates; beyond it Treeview projection dominates and is reported only. */
export const BUDGETS = [
  { level: "rust", name: "core p95 at 100k", applies: (group) => group.items >= 100000 && group.items < 1000000 && /^fuzzy/.test(group.probe), value: (group) => group.overall.p95, limit: 4 },
  { level: "rust", name: "core p95 at 1M", applies: (group) => group.items >= 1000000 && /^fuzzy/.test(group.probe), value: (group) => group.overall.p95, limit: 40 },
  { level: "ffi", name: "keystroke p95 at 100k", applies: (group) => group.items >= 100000 && group.pipeline !== "old_list", value: (group) => group.overall.p95, limit: 8 },
  { level: "e2e", name: "fire to visible p95 up to 50k", applies: (group) => group.items <= 50000, value: (group) => group.metrics.fire_to_visible_ms.p95, limit: 50 },
]

export function summarize(records) {
  return {
    rust: summarizeRust(records.filter((record) => record.level === "rust")),
    ffi: summarizeFfi(records.filter((record) => record.level === "ffi")),
    e2e: summarizeE2e(records.filter((record) => record.level === "e2e")),
  }
}

const number = (value, digits = 3) => (value == null || Number.isNaN(value) ? "—" : value.toFixed(digits))
const percent = (value) => (value == null ? "—" : `${(value * 100).toFixed(1)}%`)
const cell = (value) => String(value ?? "").replaceAll("|", "\\|").replace(/[\r\n]+/g, " ")

function budget(level, group) {
  const checks = BUDGETS.filter((item) => item.level === level && item.applies(group))
  return checks.map((item) => `${item.value(group) <= item.limit ? "pass" : "FAIL"} ${item.name} ≤ ${item.limit}`).join("; ")
}

export function report(metadata, summary) {
  const lines = [
    "# Fuzzy matcher benchmark", "",
    `Status: ${metadata.status}. Started ${metadata.started_at}; host ${metadata.host?.cpu ?? "?"} (${metadata.host?.performance_cores ?? "?"}P+${metadata.host?.efficiency_cores ?? "?"}E), ${metadata.host?.power ?? "power unknown"}; ${metadata.nvim?.[0] ?? ""}.`,
    "",
    "Times are ms. `Cal ms` is each process's fixed CPU calibration loop and `Slow` counts processes over 1.3 times the level's median, which likely ran on slower cores. Per-query values are medians within a process, reduced across processes by median. `p50/p95/max` describe queries (L1/L2) or pooled keystrokes (L3); `proc` is the median of per-process medians and `cv` its run-to-run variation. A process-level p95 appears only with at least 20 processes. See metadata.json for inputs, commands and conditions.",
  ]
  if (summary.rust.length) {
    lines.push("", "## L1 Rust core (no FFI)", "", "| Corpus | Items | Probe | Threads | Runs | Cal ms | Slow | p50 | p95 | max | proc | cv | len1 p95 | len3 p95 | len7+ p95 | Budget |", "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
    for (const group of summary.rust) {
      lines.push(`| ${cell(group.corpus)} | ${group.items} | ${cell(group.probe)} | ${group.threads} | ${group.runs} | ${number(group.calibration_ms, 1)} | ${group.slow_processes} | ${number(group.overall.p50)} | ${number(group.overall.p95)} | ${number(group.overall.max)} | ${number(group.overall.process_median)} | ${percent(group.overall.process_cv)} | ${number(group.lengths["1"].p95)} | ${number(group.lengths["3"].p95)} | ${number(group.lengths["7+"].p95)} | ${cell(budget("rust", group))} |`)
    }
  }
  if (summary.ffi.length) {
    lines.push("", "## L2 FFI (headless, per keystroke)", "", "| Corpus | Items | Pipeline | Runs | Cal ms | Slow | p50 | p95 | max | proc | cv | cold | alloc p50 KiB | alloc p95 KiB | Stages p50 | Budget |", "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
    for (const group of summary.ffi) {
      const stages = Object.entries(group.stages).map(([name, value]) => `${name} ${number(value.p50)}`).join(", ")
      lines.push(`| ${cell(group.corpus)} | ${group.items} | ${cell(group.pipeline)} | ${group.runs} | ${number(group.calibration_ms, 1)} | ${group.slow_processes} | ${number(group.overall.p50)} | ${number(group.overall.p95)} | ${number(group.overall.max)} | ${number(group.overall.process_median)} | ${percent(group.overall.process_cv)} | ${number(group.cold_ms)} | ${number(group.allocated_kib.p50, 0)} | ${number(group.allocated_kib.p95, 0)} | ${cell(stages)} | ${cell(budget("ffi", group))} |`)
    }
  }
  if (summary.e2e.length) {
    lines.push("", "## L3 end to end (real keystrokes, parent-observed flush)", "",
      "Keystroke times are pooled over keystrokes (labelled pooled); `proc` columns are medians of per-process medians. Superseded results were matched but replaced before reaching the screen; unchanged keystrokes left the header total as it was.", "",
      "| Case | Impl | Runs | Cal ms | Slow | Keys | fire→visible p50 | p95 | max | proc | cv | key→visible p50 | p95 | match p50 | p95 | display p50 | superseded | unchanged | unsettled | open | CPU/seq | Budget |",
      "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
    for (const group of summary.e2e) {
      const fire = group.metrics.fire_to_visible_ms, key = group.metrics.key_to_visible_ms, match = group.metrics.match_ms
      lines.push(`| ${cell(group.case)} | ${cell(group.implementation)} | ${group.runs} | ${number(group.calibration_ms, 1)} | ${group.slow_processes} | ${group.keystrokes} | ${number(fire.p50, 1)} | ${number(fire.p95, 1)} | ${number(fire.max, 1)} | ${number(fire.process_median, 1)} | ${percent(fire.process_cv)} | ${number(key.p50, 1)} | ${number(key.p95, 1)} | ${number(match.p50, 1)} | ${number(match.p95, 1)} | ${number(group.metrics.display_ms.p50, 1)} | ${group.superseded} | ${group.unchanged} | ${group.unsettled} | ${number(group.open_visible_ms, 0)} | ${number(group.sequence_cpu_ms, 0)} | ${cell(budget("e2e", group))} |`)
    }
    const implementations = [...new Set(summary.e2e.map((group) => group.implementation))]
    if (implementations.length > 1) {
      lines.push("", "### L3 comparison", "", `Relative change of ${implementations[1]} against ${implementations[0]} (negative is faster).`, "", "| Case | fire→visible p50 | fire→visible p95 | match p50 | key→visible p50 |", "| --- | ---: | ---: | ---: | ---: |")
      for (const name of [...new Set(summary.e2e.map((group) => group.case))]) {
        const base = summary.e2e.find((group) => group.case === name && group.implementation === implementations[0])
        const next = summary.e2e.find((group) => group.case === name && group.implementation === implementations[1])
        if (!base || !next) continue
        const delta = (metric, field) => {
          const before = base.metrics[metric][field], after = next.metrics[metric][field]
          return before ? percent((after - before) / before) : "—"
        }
        lines.push(`| ${cell(name)} | ${delta("fire_to_visible_ms", "p50")} | ${delta("fire_to_visible_ms", "p95")} | ${delta("match_ms", "p50")} | ${delta("key_to_visible_ms", "p50")} |`)
      }
    }
    const errors = summary.e2e.filter((group) => group.errors.length)
    if (errors.length) lines.push("", "Reported errors:", ...errors.map((group) => `- ${cell(group.case)} ${cell(group.implementation)}: ${cell(group.errors.join("; "))}`))
  }
  lines.push("")
  return lines.join("\n")
}

export function analyze(directory) {
  const metadata = JSON.parse(readFileSync(join(directory, "metadata.json"), "utf8"))
  const path = join(directory, "results.jsonl")
  const records = existsSync(path) ? readFileSync(path, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line)) : []
  const summary = summarize(records)
  writeFileSync(join(directory, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`)
  writeFileSync(join(directory, "report.md"), report(metadata, summary))
  return summary
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 3) throw new Error(`usage: node ${fileURLToPath(import.meta.url)} RESULT_DIRECTORY`)
  analyze(resolve(process.argv[2]))
}
