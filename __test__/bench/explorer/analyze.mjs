import { readFileSync, writeFileSync } from "node:fs"
import { join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

function median(values) {
  const sorted = [...values].sort((a, b) => a - b),
    middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

export function summarize(trials) {
  if (!trials.length) throw new Error("no benchmark results")
  const groups = new Map(),
    identities = new Set()
  for (const trial of trials) {
    if (trial.schema_version !== 1) throw new Error("unsupported result schema")
    const key = JSON.stringify([trial.case, trial.mode, trial.implementation])
    const identity = `${key}:${trial.trial}`
    if (identities.has(identity)) throw new Error(`duplicate run: ${identity}`)
    identities.add(identity)
    const group = groups.get(key) ?? {
      case: trial.case,
      mode: trial.mode,
      implementation: trial.implementation,
      metrics: {},
    }
    groups.set(key, group)
    const metrics = new Map()
    function add(name, value) {
      if (!Number.isFinite(value) || value < 0) throw new Error(`invalid metric ${name}: ${value}`)
      const values = metrics.get(name) ?? []
      values.push(value)
      metrics.set(name, values)
    }
    let expansions = 0
    for (const item of trial.operations) {
      const kind = item.kind === "expand" ? (++expansions === 1 ? "expand_cold" : "expand_warm") : item.kind
      for (const field of ["visible_ms", "ready_ms", "body_ms", "max_tick_gap_ms"]) {
        if (item[field] !== undefined) add(`${kind}.${field}`, item[field])
      }
    }
    for (const phase of ["baseline", "open_memory", "final_memory"]) {
      const memory = trial[phase]
      add(`${phase}.rss_mib`, memory.rss_kib / 1024)
      add(`${phase}.lua_heap_mib`, memory.lua_heap_kib / 1024)
      if (memory.retained) add(`${phase}.rust_retained_mib`, memory.retained.retained_bytes / 1048576)
    }
    for (const [name, values] of metrics) {
      const metric = group.metrics[name] ?? { medians: [], observations: 0 }
      metric.medians.push(median(values))
      metric.observations += values.length
      group.metrics[name] = metric
    }
  }
  for (const group of groups.values()) {
    for (const [name, metric] of Object.entries(group.metrics)) {
      const values = metric.medians.sort((a, b) => a - b)
      group.metrics[name] = {
        runs: values.length,
        observations: metric.observations,
        median: median(values),
        min: values[0],
        max: values.at(-1),
        ...(values.length >= 20 ? { p95: values[Math.ceil(values.length * 0.95) - 1] } : {}),
      }
    }
  }
  return { schema_version: 1, groups: [...groups.values()] }
}

export function analyze(directory) {
  const metadata = JSON.parse(readFileSync(join(directory, "metadata.json"), "utf8"))
  const trials = readFileSync(join(directory, "results.jsonl"), "utf8")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line))
  const summary = summarize(trials)
  writeFileSync(join(directory, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`)
  const lines = [
    "# Explorer Widget benchmark",
    "",
    `Run status: ${metadata.status}. Completed processes: ${trials.length}.`,
    "",
    "Values are medians across independent processes, after taking each process's median for repeated operations.",
    "Times are ms. Memory is MiB after full GC. RSS, Lua heap and Rust retained accounting overlap; do not add them.",
    "Git collection and LSP are disabled. Empty Git notification measures unchanged notification handling only.",
    "See metadata.json for commits, dirty worktrees, native module hashes and measurement conditions.",
    "",
    "| Case | Mode | Implementation | Runs | First flush | Ready | Cursor flush | Refresh ready | Empty Git notification | Open RSS | Final RSS |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
  ]
  const value = (group, key) => group.metrics[key]?.median.toFixed(3) ?? "—"
  for (const group of summary.groups) {
    lines.push(
      `| ${group.case} | ${group.mode} | ${group.implementation} | ${group.metrics["open.ready_ms"]?.runs ?? 0} | ${[
        "open.visible_ms",
        "open.ready_ms",
        "cursor.visible_ms",
        "refresh.ready_ms",
        "empty_git_notification.ready_ms",
        "open_memory.rss_mib",
        "final_memory.rss_mib",
      ]
        .map((key) => value(group, key))
        .join(" | ")} |`,
    )
  }
  const branches = summary.groups.filter((group) => group.metrics["expand_cold.visible_ms"])
  if (branches.length) {
    lines.push(
      "",
      "| Case | Implementation | Cold expand flush | Warm expand flush | Collapse flush |",
      "| --- | --- | ---: | ---: | ---: |",
    )
    for (const group of branches) {
      lines.push(
        `| ${group.case} | ${group.implementation} | ${["expand_cold.visible_ms", "expand_warm.visible_ms", "collapse.visible_ms"].map((key) => value(group, key)).join(" | ")} |`,
      )
    }
  }
  lines.push(
    "",
    "Cold-open runs below 20 do not report p95. Raw operations and per-metric sample counts are retained in results.jsonl and summary.json.",
    "",
  )
  writeFileSync(join(directory, "report.md"), lines.join("\n"))
  return summary
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 3) throw new Error("usage: node analyze.mjs RESULT_DIRECTORY")
  analyze(resolve(process.argv[2]))
}
