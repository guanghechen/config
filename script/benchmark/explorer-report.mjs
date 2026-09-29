import { existsSync, readFileSync, writeFileSync } from "node:fs"
import { join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

function median(values) {
  const sorted = [...values].sort((a, b) => a - b),
    middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

function statistics(values, observations = values.length) {
  const sorted = [...values].sort((a, b) => a - b)
  return {
    runs: sorted.length, observations,
    median: median(sorted), min: sorted[0], max: sorted.at(-1),
    ...(sorted.length >= 20 ? { p95: sorted[Math.ceil(sorted.length * 0.95) - 1] } : {}),
  }
}

export function summarize(trials) {
  if (!trials.length) throw new Error("no benchmark results")
  const groups = new Map(),
    identities = new Set()
  for (const trial of trials) {
    if (trial.schema_version !== 2) throw new Error("unsupported result schema; rerun with schema 2 measurements")
    if (!/^[a-f0-9]{64}$/.test(trial.input_fingerprint ?? "")) throw new Error("missing or invalid input fingerprint")
    const key = JSON.stringify([trial.case, trial.mode, trial.implementation])
    const identity = `${key}:${trial.trial}`
    if (identities.has(identity)) throw new Error(`duplicate run: ${identity}`)
    identities.add(identity)
    const group = groups.get(key) ?? {
      case: trial.case,
      mode: trial.mode,
      implementation: trial.implementation,
      scope: trial.scope ?? "widget",
      input_fingerprint: trial.input_fingerprint,
      metrics: {},
    }
    if (group.input_fingerprint !== trial.input_fingerprint) throw new Error(`mixed input fingerprints: ${key}`)
    if (group.scope !== (trial.scope ?? "widget")) throw new Error(`mixed measurement scopes: ${key}`)
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
      for (const [field, value] of Object.entries(item)) {
        if (field.endsWith("_ms") || ["mib_per_second", "files_per_second", "observer_rpcs", "readiness_checks"].includes(field)) add(`${kind}.${field}`, value)
      }
    }
    for (const phase of ["baseline", "open_memory", "final_memory"]) {
      const memory = trial[phase]
      if (!memory) continue
      if (!memory.process_memory_kind) throw new Error("missing process-memory measurement definition")
      if (group.memory_kind && group.memory_kind !== memory.process_memory_kind) throw new Error("incompatible memory measurements")
      group.memory_kind = memory.process_memory_kind
      add(`${phase}.process_memory_mib`, memory.process_memory_bytes / 1048576)
      add(`${phase}.lua_heap_mib`, memory.lua_heap_kib / 1024)
      if (memory.retained) add(`${phase}.rust_retained_mib`, memory.retained.retained_bytes / 1048576)
    }
    for (const [name, values] of metrics) {
      const metric = group.metrics[name] ?? { medians: [], observations: 0, maximum_observation: 0 }
      metric.medians.push(median(values))
      metric.observations += values.length
      metric.maximum_observation = Math.max(metric.maximum_observation, ...values)
      group.metrics[name] = metric
    }
  }
  for (const group of groups.values()) {
    for (const [name, metric] of Object.entries(group.metrics)) {
      group.metrics[name] = { ...statistics(metric.medians, metric.observations), maximum_observation: metric.maximum_observation }
    }
  }
  return { schema_version: 2, groups: [...groups.values()] }
}

export function summarizeProbes(probes) {
  const groups = new Map()
  function add(caseName, scenario, implementation, record, memoryKind) {
    const key = JSON.stringify([caseName, scenario, implementation])
    const group = groups.get(key) ?? { case: caseName, scenario, implementation, memory_kind: memoryKind, metrics: {} }
    if (group.memory_kind !== memoryKind) throw new Error("incompatible probe memory measurements")
    groups.set(key, group)
    for (const [name, value] of Object.entries(record)) {
      if (!/(_ms|_percent|process_memory_mib)$/.test(name) && !["job_polls", "owner_polls", "redraws", "redraw_notifications"].includes(name)) continue
      const values = Array.isArray(value) ? value : [value]
      if (!values.length) continue
      if (values.some((item) => !Number.isFinite(item) || item < 0)) throw new Error(`invalid probe metric ${name}`)
      const metric = group.metrics[name] ?? { medians: [], observations: 0 }
      metric.medians.push(median(values))
      metric.observations += values.length
      group.metrics[name] = metric
    }
  }
  for (const [caseName, outputs] of Object.entries(probes)) {
    for (const output of outputs) {
      const memoryKind = output.memory_measurement?.kind
      if (["idle", "watch", "jobs_activity"].includes(caseName)) {
        for (const record of output.records) add(caseName, record.phase ?? record.kind, record.implementation ?? "native", record, memoryKind)
      } else if (caseName === "root_watch") {
        for (const record of output.records) add(caseName, "idle_97_directories", "native", record.idle, memoryKind)
      } else if (caseName === "full_config") {
        for (const sample of output.samples) {
          add(caseName, "cursor_during_refresh", "native", { cursor_worst_ms: sample.cursor_worst_ms }, memoryKind)
          for (const operation of sample.operations) add(caseName, operation.kind, "native", operation, memoryKind)
        }
      } else if (caseName === "lsp") {
        add(caseName, "rename", "native", output.timings, memoryKind)
      } else if (caseName === "soak") {
        add(caseName, "session", "native", {
          cycle_watch_median_ms: output.watch_change_to_flush_ms.median,
          first_hidden_process_memory_mib: output.samples[0].process_memory_bytes / 1048576,
          last_hidden_process_memory_mib: output.samples.at(-1).process_memory_bytes / 1048576,
          before_trace_flush_process_memory_mib: output.final.before_trace_flush.memory.process_memory_bytes / 1048576,
          after_trace_flush_process_memory_mib: output.final.memory.process_memory_bytes / 1048576,
        }, memoryKind)
      }
    }
  }
  for (const group of groups.values()) {
    for (const [name, metric] of Object.entries(group.metrics)) group.metrics[name] = statistics(metric.medians, metric.observations)
  }
  return [...groups.values()]
}

export function analyze(directory) {
  const metadata = JSON.parse(readFileSync(join(directory, "metadata.json"), "utf8"))
  const rawPath = join(directory, "results.jsonl")
  const trials = (existsSync(rawPath) ? readFileSync(rawPath, "utf8") : "")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line))
  const summary = trials.length ? summarize(trials) : { schema_version: 2, groups: [] }
  const probes = {}
  for (const entry of metadata.coverage ?? []) {
    if (entry.status !== "passed" || !entry.result?.startsWith("probes/")) continue
    if (!/^[a-z0-9_]+$/.test(entry.case) || entry.result !== `probes/${entry.case}.json`) throw new Error("invalid probe result path")
    probes[entry.case] = JSON.parse(readFileSync(join(directory, entry.result), "utf8"))
  }
  summary.probes = summarizeProbes(probes)
  writeFileSync(join(directory, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`)
  const lines = [
    "# Explorer benchmark and acceptance",
    "",
    `Run status: ${metadata.status}. Comparable process records: ${trials.length}. Acceptance records are stored separately.`,
    "",
    "Values are medians across independent processes, after taking each process's median for repeated operations.",
    "Times are ms unless the metric says otherwise. Memory snapshots use MiB after full GC; process memory, Lua heap and Rust accounting overlap.",
    "The process-memory definition is recorded per group: physical_footprint on macOS/libuv 1.53+, RSS on other supported hosts, or an explicitly unresolved libuv reading.",
    "Widget microbenchmarks preload modules and disable Git/LSP collection. Other cases retain their own measurement boundaries.",
    "See metadata.json for actual source fingerprints, build receipts, artifacts, commands, skipped cases and conditions.",
    "",
    "## Coverage",
    "",
    "| Case | Comparison | Status | Details |",
    "| --- | --- | --- | --- |",
  ]
  const cell = (value) => String(value ?? "").replaceAll("|", "\\|").replace(/[\r\n]+/g, " ")
  for (const entry of metadata.coverage ?? []) {
    lines.push(`| ${cell(entry.case)} | ${cell(entry.comparison)} | ${cell(entry.status)} | ${cell(entry.reason ?? entry.result ?? "")} |`)
  }
  lines.push("", "## Build provenance", "", "| Implementation | Native receipt | Native input hash | Runtime input hash |", "| --- | --- | --- | --- |")
  for (const [name, repository] of Object.entries(metadata.repositories)) {
    const provenance = repository.provenance
    lines.push(`| ${cell(name)} | ${cell(provenance?.status ?? "unverified")} | ${cell(provenance?.source?.sha256 ?? "")} | ${cell(repository.runtime?.sha256 ?? "")} |`)
  }
  if (metadata.repository_metadata_changes?.length) lines.push("", `${metadata.repository_metadata_changes.length} checkout Git metadata change(s) were recorded; measured content fingerprints remained unchanged. See metadata.json.`)
  lines.push(
    "", "## Widget comparisons", "",
    "| Case | Mode | Implementation | Runs | First flush | Ready | Cursor flush | Scroll flush | Selection ready | Visual selection ready | Refresh ready | Reopen flush |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
  )
  const value = (group, key) => group.metrics[key]?.median.toFixed(3) ?? "—"
  for (const group of summary.groups.filter((item) => item.scope === "widget")) {
    lines.push(
      `| ${group.case} | ${group.mode} | ${group.implementation} | ${group.metrics["open.ready_ms"]?.runs ?? 0} | ${[
        "open.visible_ms",
        "open.ready_ms",
        "cursor.visible_ms",
        "scroll.visible_ms",
        "selection.ready_ms",
        "visual_selection.ready_ms",
        "refresh.ready_ms",
        "reopen.visible_ms",
      ]
        .map((key) => value(group, key))
        .join(" | ")} |`,
    )
  }
  lines.push("", "## Input latency and observation", "",
    "Process p95 is the p95 of process-level medians, reported only with at least 20 independent processes. Observed max retains the slowest individual operation; it is not a percentile. Readiness checks run inside the measured process. Observer RPCs count parent readiness requests during timing.", "",
    "| Case | Mode | Implementation | Operation | Processes | Median ms | Process p95 ms | Observed max ms | Observer RPCs max | Readiness checks median |",
    "| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
  for (const group of summary.groups) {
    for (const kind of ["cursor", "scroll", "selection", "visual_selection", "startup", "first_explorer", "git_refresh", "copy"]) {
      const metric = group.metrics[`${kind}.${["cursor", "scroll"].includes(kind) ? "visible_ms" : "ready_ms"}`]
      if (!metric) continue
      const rpc = group.metrics[`${kind}.observer_rpcs`]
      lines.push(`| ${cell(group.case)} | ${group.mode} | ${group.implementation} | ${kind} | ${metric.runs} | ${metric.median.toFixed(3)} | ${metric.p95?.toFixed(3) ?? "—"} | ${metric.maximum_observation.toFixed(3)} | ${rpc?.maximum_observation ?? "—"} | ${value(group, `${kind}.readiness_checks`)} |`)
    }
  }
  lines.push("", "## Process memory", "", "| Case | Mode | Implementation | Definition | Open MiB | Final MiB |", "| --- | --- | --- | --- | ---: | ---: |")
  for (const group of summary.groups.filter((item) => item.memory_kind)) {
    lines.push(`| ${cell(group.case)} | ${cell(group.mode)} | ${cell(group.implementation)} | ${cell(group.memory_kind)} | ${value(group, "open_memory.process_memory_mib")} | ${value(group, "final_memory.process_memory_mib")} |`)
  }
  const comparisons = summary.groups.filter((item) => item.scope !== "widget")
  if (comparisons.length) {
    lines.push("", "## Startup, Git and filesystem comparisons", "", "| Case | Implementation | Metric | Runs | Median | Min | Max |", "| --- | --- | --- | ---: | ---: | ---: | ---: |")
    for (const group of comparisons) {
      for (const [name, metric] of Object.entries(group.metrics).filter(([name]) => !name.includes("memory") && !name.startsWith("baseline."))) {
        lines.push(`| ${cell(group.case)} | ${cell(group.implementation)} | ${cell(name)} | ${metric.runs} | ${metric.median.toFixed(3)} | ${metric.min.toFixed(3)} | ${metric.max.toFixed(3)} |`)
      }
    }
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
  if (summary.probes.length) {
    lines.push("", "## Probe measurements", "",
      "Native-only probes are acceptance measurements. Watch events are reduced within each process; soak reports process-level cycle medians and equivalent lifecycle snapshots. Memory definitions are retained in summary.json and the raw probe. Job UI assertions remain in its raw result.", "",
      "| Case | Scenario | Implementation | Metric | Processes | Median | Min | Max |",
      "| --- | --- | --- | --- | ---: | ---: | ---: | ---: |")
    for (const group of summary.probes) {
      for (const [name, metric] of Object.entries(group.metrics)) {
        lines.push(`| ${cell(group.case)} | ${cell(group.scenario)} | ${cell(group.implementation)} | ${cell(name)} | ${metric.runs} | ${metric.median.toFixed(3)} | ${metric.min.toFixed(3)} | ${metric.max.toFixed(3)} |`)
      }
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
  if (process.argv.length !== 3) throw new Error(`usage: node ${fileURLToPath(import.meta.url)} RESULT_DIRECTORY`)
  analyze(resolve(process.argv[2]))
}
