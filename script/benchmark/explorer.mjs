import { spawn, spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import {
  appendFileSync, closeSync, existsSync, mkdirSync, mkdtempSync, openSync, readFileSync,
  readdirSync, realpathSync, rmSync, writeFileSync, writeSync,
} from "node:fs"
import { arch, cpus, homedir, platform, release, tmpdir, totalmem } from "node:os"
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { parseArgs } from "node:util"

import { fileHash, inspectArtifact, pluginInputs, runtimeInputs } from "./provenance.mjs"
import { analyze } from "./explorer-report.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const checkout = resolve(here, "../..")
const drivers = join(checkout, "__test__/bench/explorer")
const nativeName = process.platform === "win32" ? "yoz.dll" : "yoz.so"

export const cases = [
  { name: "mixed_200", scope: "widget", entries: 200, directories: 20, branch: 0 },
  { name: "flat_1000", scope: "widget", entries: 1000, directories: 0, branch: 0 },
  { name: "flat_10000", scope: "widget", entries: 10000, directories: 0, branch: 0 },
  { name: "branch_1000_plus_9000", scope: "widget", entries: 9000, directories: 0, branch: 1000 },
  { name: "flat_50000", scope: "widget", entries: 50000, directories: 0, branch: 0 },
  { name: "startup_200", scope: "startup", entries: 200 },
  { name: "git_1000", scope: "git", entries: 1000 },
  { name: "copy_64mib", scope: "copy", entries: 1, bytes: 64 * 1048576, files: 1 },
  { name: "copy_100_files", scope: "copy", entries: 1, bytes: 400, files: 100 },
  { name: "copy_1000_files", scope: "copy", entries: 1, bytes: 4000, files: 1000 },
  { name: "copy_10000_files", scope: "copy", entries: 1, bytes: 40000, files: 10000 },
  { name: "copy_1000_4kib", scope: "copy", entries: 1, bytes: 1000 * 4096, files: 1000 },
  { name: "copy_1000_64kib", scope: "copy", entries: 1, bytes: 1000 * 65536, files: 1000 },
  { name: "copy_1000_expanded", scope: "copy", entries: 1, bytes: 4000, files: 1000, expanded: true },
  { name: "copy_1000_outside", scope: "copy", entries: 1, bytes: 4000, files: 1000, outside: true },
  { name: "navigation", scope: "acceptance", driver: "navigation.lua", comparison: "native repeated navigation and root recovery" },
  { name: "active_loading", scope: "acceptance", driver: "loading.lua", comparison: "native input and cancellation during active scans" },
  { name: "idle", scope: "acceptance", driver: "idle.lua", comparison: "legacy/native idle" },
  { name: "watch", scope: "acceptance", driver: "activity.lua", comparison: "native watch activity" },
  { name: "jobs_activity", scope: "acceptance", driver: "activity.lua", comparison: "native Job activity" },
  { name: "root_watch", scope: "acceptance", driver: "root_watch.lua", comparison: "native macOS recursive watch" },
  { name: "soak", scope: "acceptance", driver: "soak.lua", comparison: "native long-session acceptance" },
  { name: "full_config", scope: "acceptance", driver: "full_config.lua", comparison: "native full-config actions" },
  { name: "jobs_ui", scope: "acceptance", driver: "jobs_ui.lua", comparison: "native Job/exit UI acceptance" },
  { name: "lsp", scope: "acceptance", driver: "lsp.lua", comparison: "native installed-server rename" },
]

function capture(command, args, cwd, raw = false) {
  const result = spawnSync(command, args, {
    cwd, encoding: "utf8", timeout: 30000,
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
  })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`${command}: ${result.stderr || result.stdout}`)
  return raw ? result.stdout : result.stdout.trim()
}

export function parseStatus(raw) {
  if (!raw) return []
  if (!raw.endsWith("\0")) throw new Error("unterminated porcelain status")
  const entries = raw.slice(0, -1).split("\0"), result = []
  for (let index = 0; index < entries.length; index++) {
    if (!/^[ MADRCUT?!]{2} [\s\S]/.test(entries[index])) throw new Error("invalid porcelain status entry")
    const status = entries[index].slice(0, 2), path = entries[index].slice(3)
    const entry = { status, path }
    if (/[RC]/.test(status)) {
      entry.from = entries[++index]
      if (!entry.from) throw new Error("missing porcelain rename/copy source")
    }
    result.push(entry)
  }
  return result
}

export function inputFingerprint(input) {
  function canonical(value) {
    if (Array.isArray(value)) return value.map(canonical)
    if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]))
    return value
  }
  return createHash("sha256").update(JSON.stringify(canonical(input))).digest("hex")
}

export function measuredRepository({ path, native_module, provenance, runtime }) {
  return { path, native_module, provenance, runtime }
}

function repository(path, library) {
  const provenance = inspectArtifact(path, library)
  if (provenance.status === "mismatch") throw new Error(`native source/artifact mismatch: ${path}; use --build`)
  return {
    path,
    head: capture("git", ["rev-parse", "--verify", "--end-of-options", "HEAD^{commit}"], path),
    tree: capture("git", ["rev-parse", "--verify", "--end-of-options", "HEAD^{tree}"], path),
    worktree: parseStatus(capture("git", ["--no-optional-locks", "--literal-pathspecs", "status", "--porcelain=v1", "-z", "--untracked-files=all"], path, true)),
    native_module: library,
    provenance,
    runtime: runtimeInputs(path),
  }
}

function capturePlugins(plugins) {
  return plugins.map(({ name, path, locked_commit }) => {
    if (!existsSync(path)) return { name, path, locked_commit, status: "absent" }
    const input = { name, path, locked_commit, status: "verified", content: pluginInputs(path) }
    if (existsSync(join(path, ".git"))) {
      input.installed_commit = capture("git", ["rev-parse", "--verify", "--end-of-options", "HEAD^{commit}"], path)
      input.worktree = parseStatus(capture("git", ["--no-optional-locks", "--literal-pathspecs", "status", "--porcelain=v1", "-z", "--untracked-files=all"], path, true))
    }
    return input
  })
}

function harnessHashes() {
  const names = [
    ...readdirSync(here).filter((name) => name.endsWith(".mjs")).map((name) => join("script/benchmark", name)),
    ...readdirSync(drivers).filter((name) => name.endsWith(".lua")).map((name) => join("__test__/bench/explorer", name)),
    "__test__/support/ui.lua", "__test__/support/ui_grid.lua", "__test__/fixtures/era/m/explorer/full_config_init.lua",
    "script/build.mjs",
  ]
  return Object.fromEntries(names.map((name) => name.split(sep).join("/")).sort().map((name) => [name, fileHash(join(checkout, name))]))
}

function execute(command, args, timeout, signal, env = {}) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(command, args, {
      cwd: checkout, stdio: ["ignore", "pipe", "pipe"], detached: process.platform !== "win32",
      env: { ...process.env, GIT_OPTIONAL_LOCKS: "0", ...env },
    })
    let stdout = "", stderr = "", failure
    function stop(reason) {
      failure ??= new Error(reason)
      if (!child.pid) return
      if (process.platform === "win32") {
        spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" })
      } else {
        try { process.kill(-child.pid, "SIGKILL") } catch (error) { if (error.code !== "ESRCH") throw error }
      }
    }
    const timer = setTimeout(() => stop(`process exceeded ${timeout} ms`), timeout)
    const abort = () => stop("benchmark interrupted")
    signal.addEventListener("abort", abort, { once: true })
    child.stdout.on("data", (data) => { stdout += data })
    child.stderr.on("data", (data) => { stderr += data })
    child.on("error", (error) => { failure = error })
    child.on("close", (code) => {
      clearTimeout(timer)
      signal.removeEventListener("abort", abort)
      if (failure || code !== 0) {
        const error = new Error(failure?.message ?? `${command} exited ${code}`)
        Object.assign(error, { stdout, stderr, code })
        reject(error)
      } else resolveRun({ stdout, stderr })
    })
    if (signal.aborted) abort()
  })
}

function copyPaths(folder, scenario) {
  const directory = scenario.outside ? join(folder, "view") : folder
  return {
    directory,
    source: join(directory, scenario.files > 1 ? "source" : "source.bin"),
    target: join(scenario.outside ? join(folder, "outside") : folder, scenario.files > 1 ? "zz-copied" : "zz-copied.bin"),
  }
}

function populate(folder, scenario) {
  mkdirSync(folder)
  if (scenario.scope === "copy") {
    const paths = copyPaths(folder, scenario)
    if (scenario.outside) {
      mkdirSync(paths.directory)
      mkdirSync(dirname(paths.target))
    }
    if (scenario.files > 1) {
      mkdirSync(paths.source)
      const size = scenario.bytes / scenario.files
      if (!Number.isInteger(size)) throw new Error("copy fixture needs an integer file size")
      const contents = size === 4 ? Buffer.from("data") : Buffer.alloc(size, 0x61)
      for (let index = 0; index < scenario.files; index++) writeFileSync(join(paths.source, `file-${index}.txt`), contents, { flag: "wx" })
    } else {
      const fd = openSync(paths.source, "wx")
      try {
        const block = Buffer.alloc(1048576, 0x61)
        for (let offset = 0; offset < scenario.bytes; offset += block.length) {
          let written = 0
          const size = Math.min(block.length, scenario.bytes - offset)
          while (written < size) written += writeSync(fd, block, written, size - written)
        }
      } finally { closeSync(fd) }
    }
    return
  }
  const files = scenario.scope === "startup" ? join(folder, "files") : folder
  if (scenario.scope === "startup") { mkdirSync(files); mkdirSync(join(folder, "state")) }
  for (let index = 0; index < (scenario.directories ?? 0); index++) mkdirSync(join(files, `directory-${String(index).padStart(3, "0")}`))
  const suffix = scenario.scope === "startup" ? "txt" : "lua"
  for (let index = 0; index < scenario.entries - (scenario.directories ?? 0); index++) {
    writeFileSync(join(files, `file-${String(index).padStart(5, "0")}.${suffix}`), scenario.scope === "git" ? "base\n" : "", { flag: "wx" })
  }
  if (scenario.branch) {
    mkdirSync(join(folder, "a-branch"))
    for (let index = 0; index < scenario.branch; index++) writeFileSync(join(folder, "a-branch", `inside-${String(index).padStart(5, "0")}.lua`), "", { flag: "wx" })
  }
  if (scenario.scope === "git") {
    writeFileSync(join(folder, ".gitignore"), "a-ignored.lua\n")
    writeFileSync(join(folder, "a-ignored.lua"), "ignored\n")
    // Only this newly created disposable repository receives Git writes.
    capture("git", ["init", "-q", folder], checkout)
    capture("git", ["-C", folder, "add", "--all"], checkout)
    writeFileSync(join(folder, "b-untracked.lua"), "untracked\n")
  }
}

function resetFixture(folder, scenario) {
  if (scenario.scope === "copy") rmSync(copyPaths(folder, scenario).target, { recursive: true, force: true })
  if (scenario.scope === "git") writeFileSync(join(folder, "file-00000.lua"), "base\n")
  if (scenario.scope === "startup") {
    rmSync(join(folder, "state"), { recursive: true, force: true })
    mkdirSync(join(folder, "state"))
  }
}

function verifyCopy(folder, scenario) {
  const paths = copyPaths(folder, scenario)
  const names = scenario.files > 1 ? readdirSync(paths.source) : [""]
  for (const name of names) {
    const source = scenario.files > 1 ? join(paths.source, name) : paths.source
    const target = scenario.files > 1 ? join(paths.target, name) : paths.target
    if (fileHash(source) !== fileHash(target)) throw new Error(`copy content mismatch: ${name}`)
  }
  if (scenario.files > 1 && readdirSync(paths.target).length !== names.length) throw new Error("copy has unexpected entries")
}

export function probeArguments(name, { samples, repeats, cycles, baseline, lsp }) {
  switch (name) {
    case "idle": return [baseline ?? "-", String(samples)]
    case "watch": return ["watch", String(samples)]
    case "jobs_activity": return ["jobs", String(samples)]
    case "navigation": return [String(samples)]
    case "active_loading": return [String(samples), "50000"]
    case "root_watch": return [String(samples)]
    case "soak": return [String(cycles), "1000"]
    case "full_config": return [String(samples), String(Math.min(1000, Math.max(10, repeats * 40)))]
    case "jobs_ui": return [String(samples)]
    case "lsp": return [lsp]
    default: throw new Error(`unknown probe: ${name}`)
  }
}

async function main() {
  const { values } = parseArgs({ options: {
    current: { type: "string", default: checkout }, baseline: { type: "string" },
    native: { type: "string" }, "baseline-native": { type: "string" },
    samples: { type: "string", default: "3" }, repeats: { type: "string", default: "3" },
    case: { type: "string", multiple: true }, mode: { type: "string", default: "both" },
    output: { type: "string" }, nvim: { type: "string", default: "nvim" },
    "timeout-ms": { type: "string", default: "600000" }, cycles: { type: "string", default: "200" },
    lsp: { type: "string", default: join(homedir(), ".local/share/nvim/mason/bin/vtsls") },
    build: { type: "boolean" }, help: { type: "boolean", short: "h" },
  } })
  if (values.help) {
    console.log(`Usage: node ${fileURLToPath(import.meta.url)} [options]
  --current PATH       Native checkout (default: this checkout)
  --baseline PATH      Legacy checkout for common A/B cases
  --native PATH        Preserved native release module (default: current/lua/yoz.so)
  --baseline-native PATH  Preserved legacy release module
  --case NAME          Repeat to select cases (default: the comprehensive matrix)
  --samples N          Independent processes per comparison/probe (default: 3)
  --repeats N          Repeated interactions within a process (default: 3)
  --mode tree|list|both Widget modes; List is native only (default: both)
  --cycles N           Long-session cycles, a positive multiple of 20 (default: 200)
  --lsp PATH           Existing vtsls executable (default: Mason's vtsls)
  --build              Build source-bound release artifacts into the result directory, offline
  --output PATH        New result directory outside the measured/tool checkouts
  --nvim PATH          Neovim executable (default: nvim)
  --timeout-ms N       Deadline per child process (default: 600000)
Cases: ${cases.map((item) => item.name).join(", ")}`)
    return
  }
  const samples = Number(values.samples), repeats = Number(values.repeats), timeout = Number(values["timeout-ms"]), cycles = Number(values.cycles)
  if (![samples, repeats].every((n) => Number.isInteger(n) && n >= 1 && n <= 100)) throw new Error("samples and repeats must be integers from 1 through 100")
  if (!Number.isInteger(timeout) || timeout < 1000) throw new Error("timeout-ms must be an integer >= 1000")
  if (!Number.isInteger(cycles) || cycles < 20 || cycles > 10000 || cycles % 20 !== 0) throw new Error("cycles must be a multiple of 20 from 20 through 10000")
  if (!["tree", "list", "both"].includes(values.mode)) throw new Error("mode must be tree, list or both")
  if (values.build && (values.native || values["baseline-native"])) throw new Error("--build cannot be combined with explicit native modules")
  if (values["baseline-native"] && !values.baseline) throw new Error("--baseline-native requires --baseline")
  const selected = values.case ?? cases.map((item) => item.name)
  for (const name of selected) if (!cases.some((item) => item.name === name)) throw new Error(`unknown case: ${name}`)
  const scenarios = cases.filter((item) => selected.includes(item.name))
  const locations = { native: realpathSync(values.current) }
  if (values.baseline) locations.legacy = realpathSync(values.baseline)
  const nvimVersion = capture(values.nvim, ["--version"], checkout).split("\n").slice(0, 3)
  const harness = harnessHashes()
  if (values.output) {
    const destination = join(realpathSync(dirname(resolve(values.output))), resolve(values.output).split(sep).at(-1))
    for (const root of [checkout, ...Object.values(locations)]) {
      const path = relative(root, destination)
      if (path === "" || (!isAbsolute(path) && path !== ".." && !path.startsWith(`..${sep}`))) {
        throw new Error("output must be outside the measured/tool checkouts to keep inputs stable")
      }
    }
  }
  const output = values.output ? resolve(values.output) : mkdtempSync(join(tmpdir(), "explorer-bench-"))
  if (values.output) mkdirSync(output)
  mkdirSync(join(output, "probes"))
  mkdirSync(join(output, "logs"))
  const data = realpathSync(mkdtempSync(join(tmpdir(), "explorer-bench-data-")))
  const metadata = {
    schema_version: 2, started_at: new Date().toISOString(), status: "running",
    host: { platform: platform(), release: release(), arch: arch(), cpu: cpus()[0]?.model, memory_bytes: totalmem() },
    nvim: nvimVersion,
    repositories: {}, repository_metadata_changes: [], plugin_inputs: {}, samples, repeats, cycles, cases: scenarios, mode: values.mode,
    harness_sha256: harness,
    coverage: scenarios.map((scenario) => ({
      case: scenario.name,
      comparison: scenario.name === "idle" && !locations.legacy ? "native idle"
        : scenario.comparison ?? (locations.legacy && (scenario.scope !== "widget" || values.mode !== "list") ? "legacy/native" : "native only"),
      status: "not_run",
    })),
    commands: [],
    conditions: {
      order: "fresh processes; A/B and B/A alternate; no concurrent measurements",
      widget: "110x40 UI, width 44, rosepine-main, compression off; modules preloaded, Git/LSP disabled",
      startup: "fresh full-config process plus first default Explorer; embedded UI handshake included, context isolated, automatic IM disabled; locally installed plugins/caches retained",
      plugins: "one unmeasured startup discovers each full-config environment; configured plugin Lua/Vim/native/query/data/JS/Wasm contents, including ignored native libraries, are fingerprinted before samples and checked before/after cases; plugin caches are warm",
      git: "real disposable Git repository and queries; staged/untracked/ignored fixtures; changed status must reach the Explorer model; no UI-flush claim for Git ready",
      copy: "actual Explorer copy action with automatically accepted path input; dense 64 MiB file or 100/1000/10000 files, four bytes/4 KiB/64 KiB each; collapsed source, expanded source and destination outside display root are separate cases; all names and contents verified after timing; native ready includes target-follow, outside copies change native root while legacy retains it; job_ms remains the IO throughput boundary",
      observer: "comparable phases send completion notifications with zero readiness RPCs during timing; widget checks run on publication/cursor events and a 2 ms timer; copy/Git readiness checks begin only after terminal/query notification; startup uses 5 ms configuration and 2 ms first-view checks. Process/main-thread CPU and Job-terminal CPU are separate; readiness_checks and observer_rpcs audit observation work",
      caches: "source fingerprinting and fixture creation warm filesystem/page caches; not a cold-device benchmark",
      selection: "typed Tab and 100-row Visual selection; visible ends at a parent-observed UI flush with the expected selection glyph state on the target filename row inside the Explorer window, armed by a child start notification; ready separately validates published selection counts and decoration completion",
      memory: "full GC before snapshots; process memory has an explicit kind and libuv version; Lua heap/native retained accounting overlap with it",
      statistics: "within-process medians, then independent-process distributions; p95 only with at least 20 processes; acceptance probe event/cycle distributions stay separate",
      acceptance: "native-only probes are labeled as acceptance, not legacy/native performance comparisons; no packages are installed",
    },
  }
  const controller = new AbortController(), results = []
  const interrupt = () => controller.abort()
  process.on("SIGINT", interrupt)
  process.on("SIGTERM", interrupt)
  const save = () => writeFileSync(join(output, "metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`)
  const saveLog = (name, result) => {
    writeFileSync(join(output, "logs", `${name}.stdout`), result.stdout ?? "")
    writeFileSync(join(output, "logs", `${name}.stderr`), result.stderr ?? "")
  }
  console.log(`Results: ${output}`)
  try {
    save()
    const env = { NVIM_EXPLORER_BENCH_CHECKOUT: locations.native }
    for (const [implementation, path] of Object.entries(locations)) {
      const explicitLibrary = implementation === "native" ? values.native : values["baseline-native"]
      let library = explicitLibrary ? realpathSync(explicitLibrary) : join(path, "lua", nativeName)
      if (values.build) {
        mkdirSync(join(output, "native"), { recursive: true })
        const buildRoot = join(output, "native", implementation)
        const args = [join(checkout, "script/build.mjs"), "--root", path, "--output", buildRoot, "--offline"]
        metadata.commands.push({ case: "build", implementation, command: process.execPath, args })
        console.log(`Building ${implementation} release artifact`)
        const result = await execute(process.execPath, args, Math.max(timeout, 600000), controller.signal)
        saveLog(`build-${implementation}`, result)
        library = join(buildRoot, "lua", nativeName)
        rmSync(join(buildRoot, "target"), { recursive: true, force: true })
      }
      metadata.repositories[implementation] = repository(path, library)
      env[implementation === "native" ? "NVIM_EXPLORER_BENCH_NATIVE" : "NVIM_EXPLORER_BENCH_BASELINE_NATIVE"] = library
    }
    if (scenarios.some((item) => ["startup", "full_config", "jobs_ui"].includes(item.scope === "startup" ? item.scope : item.name))) {
      const scenario = { scope: "startup", entries: 200 }
      const folder = join(data, "plugin-inputs")
      populate(folder, scenario)
      const implementations = locations.legacy && scenarios.some((item) => item.scope === "startup") ? ["native", "legacy"] : ["native"]
      for (const implementation of implementations) {
        resetFixture(folder, scenario)
        const args = ["-l", join(drivers, "startup.lua"), locations[implementation], folder, implementation, String(scenario.entries)]
        metadata.commands.push({ case: "plugin_provenance", implementation, command: values.nvim, args })
        console.log(`Capturing ${implementation} plugin inputs`)
        const record = await execute(values.nvim, args, timeout, controller.signal, env)
        saveLog(`plugins-${implementation}`, record)
        metadata.plugin_inputs[implementation] = capturePlugins(JSON.parse(record.stdout).plugins)
      }
      rmSync(folder, { recursive: true })
    }
    const snapshots = JSON.stringify(Object.fromEntries(Object.entries(metadata.repositories).map(([name, repo]) => [name, measuredRepository(repo)])))
    let repositoryMetadata = JSON.stringify(Object.fromEntries(Object.entries(metadata.repositories).map(([name, { head, tree, worktree }]) => [name, { head, tree, worktree }])))
    const pluginSnapshots = JSON.stringify(metadata.plugin_inputs)
    const checkInputs = () => {
      try {
        const current = Object.fromEntries(Object.entries(metadata.repositories).map(([name, repo]) => [name, repository(repo.path, repo.native_module)]))
        const plugins = Object.fromEntries(Object.entries(metadata.plugin_inputs).map(([name, entries]) => [name, capturePlugins(entries)]))
        if (JSON.stringify(Object.fromEntries(Object.entries(current).map(([name, repo]) => [name, measuredRepository(repo)]))) !== snapshots || JSON.stringify(plugins) !== pluginSnapshots || JSON.stringify(harnessHashes()) !== JSON.stringify(metadata.harness_sha256)) {
          throw new Error("measured source, native artifact, plugin inputs or harness changed during the run")
        }
        const observed = Object.fromEntries(Object.entries(current).map(([name, { head, tree, worktree }]) => [name, { head, tree, worktree }]))
        const recorded = JSON.stringify(observed)
        if (recorded !== repositoryMetadata) {
          metadata.repository_metadata_changes.push({ observed_at: new Date().toISOString(), repositories: observed })
          repositoryMetadata = recorded
        }
      } catch (error) {
        throw new Error(`input validation failed: ${error.message}`)
      }
    }
    save()
    for (const scenario of scenarios) {
      const coverage = metadata.coverage.find((item) => item.case === scenario.name)
      coverage.status = "running"
      save()
      try {
        if (controller.signal.aborted) throw new Error("benchmark interrupted")
        checkInputs()
        if (scenario.scope === "acceptance") {
          if (scenario.name === "root_watch" && process.platform !== "darwin") {
            Object.assign(coverage, { status: "not_applicable", reason: "macOS recursive backend only" })
            continue
          }
          if (scenario.name === "lsp" && !existsSync(values.lsp)) {
            Object.assign(coverage, { status: "blocked", reason: `installed vtsls not found: ${values.lsp}` })
            continue
          }
          const iterations = scenario.name === "lsp" || scenario.name === "soak" ? samples : 1
          const records = []
          for (let trial = 1; trial <= iterations; trial++) {
            const args = ["-l", join(drivers, scenario.driver), ...probeArguments(scenario.name, { samples, repeats, cycles, baseline: locations.legacy, lsp: values.lsp })]
            metadata.commands.push({ case: scenario.name, trial, command: values.nvim, args })
            console.log(`Running ${scenario.name} ${trial}/${iterations}`)
            const record = await execute(values.nvim, args, timeout, controller.signal, env)
            saveLog(`${scenario.name}-${trial}`, record)
            records.push(JSON.parse(record.stdout))
          }
          const filename = `probes/${scenario.name}.json`
          writeFileSync(join(output, filename), `${JSON.stringify(records, null, 2)}\n`)
          Object.assign(coverage, { status: "passed", result: filename })
        } else {
          const folder = join(data, scenario.name)
          populate(folder, scenario)
          const modes = scenario.scope === "widget" ? values.mode === "both" ? ["tree", "list"] : [values.mode] : ["tree"]
          for (const mode of modes) {
            for (let trial = 1; trial <= samples; trial++) {
              const order = locations.legacy && mode === "tree" ? trial % 2 ? ["legacy", "native"] : ["native", "legacy"] : ["native"]
              for (const implementation of order) {
                resetFixture(folder, scenario)
                const repo = metadata.repositories[implementation]
                let args
                if (scenario.scope === "widget") args = ["-l", join(drivers, "measure.lua"), repo.path, folder, implementation, String(scenario.entries), String(scenario.branch), String(repeats), mode]
                else if (scenario.scope === "startup") args = ["-l", join(drivers, "startup.lua"), repo.path, folder, implementation, String(scenario.entries)]
                else {
                  const paths = scenario.scope === "copy" ? copyPaths(folder, scenario) : { directory: folder }
                  const options = scenario.scope === "copy" ? {
                    expanded: scenario.expanded ?? false,
                    outside: scenario.outside ?? false,
                    destination: relative(paths.directory, paths.target) + (scenario.files > 1 ? "/" : ""),
                  } : {}
                  args = ["-l", join(drivers, "operations.lua"), repo.path, paths.directory, implementation, scenario.scope, String(scenario.scope === "git" ? scenario.entries + 2 : scenario.entries), String(repeats), String(scenario.bytes ?? 0), String(scenario.files ?? 0), JSON.stringify(options)]
                }
                metadata.commands.push({ case: scenario.name, mode, implementation, trial, command: values.nvim, args })
                console.log(`Running ${scenario.name} ${mode} ${implementation} ${trial}/${samples}`)
                const started = performance.now()
                const record = await execute(values.nvim, args, timeout, controller.signal, env)
                saveLog(`${scenario.name}-${mode}-${implementation}-${trial}`, record)
                const result = JSON.parse(record.stdout)
                if (result.schema_version !== 2 || result.implementation !== implementation || result.mode !== mode) throw new Error("unexpected result identity/schema")
                if (result.operations.some((operation) => operation.observer_rpcs !== 0)) throw new Error("readiness RPCs must remain zero during comparable measurements")
                if (scenario.scope === "copy") { verifyCopy(folder, scenario); result.checks.content_verified = true }
                if (scenario.scope === "startup") {
                  for (const plugin of result.plugins) {
                    const captured = metadata.plugin_inputs[implementation].find((item) => item.name === plugin.name)
                    if (!captured || captured.path !== plugin.path || captured.locked_commit !== plugin.locked_commit) throw new Error("input validation failed: plugin configuration changed")
                    Object.assign(plugin, { installed_commit: captured.installed_commit, worktree: captured.worktree, input_sha256: captured.content?.sha256, input_status: captured.status })
                  }
                }
                checkInputs()
                Object.assign(result, {
                  case: scenario.name, trial, scope: scenario.scope,
                  elapsed_seconds: (performance.now() - started) / 1000,
                  input_fingerprint: inputFingerprint({
                    repo: measuredRepository(repo), harness: metadata.harness_sha256, plugins: result.plugins, plugin_inputs: metadata.plugin_inputs[implementation],
                    measurement: { host: metadata.host, nvim: metadata.nvim, conditions: metadata.conditions, scenario, repeats },
                  }),
                })
                results.push(result)
                appendFileSync(join(output, "results.jsonl"), `${JSON.stringify(result)}\n`)
              }
            }
          }
          rmSync(folder, { recursive: true })
          Object.assign(coverage, { status: "passed", result: "results.jsonl", note: scenario.scope === "widget" ? "List is native-only; Tree provides the common comparison" : undefined })
        }
        checkInputs()
      } catch (error) {
        Object.assign(coverage, { status: "failed", reason: error.message })
        saveLog(`${scenario.name}-failure`, error)
        console.error(`${scenario.name}: ${error.message}; see logs`)
        if (controller.signal.aborted || error.message.startsWith("input validation failed:")) throw error
      } finally { save() }
    }
    checkInputs()
    metadata.status = metadata.coverage.some((item) => item.status === "failed") ? "failed"
      : metadata.coverage.some((item) => item.status === "blocked") ? "incomplete" : "complete"
    if (metadata.status !== "complete") process.exitCode = 1
  } catch (error) {
    metadata.status = "failed"
    metadata.error = error.message
    saveLog("run-failure", error)
    console.error(error.message)
    process.exitCode = 1
  } finally {
    metadata.finished_at = new Date().toISOString()
    metadata.completed_runs = results.length
    try {
      save()
      analyze(output)
    } catch (error) {
      metadata.status = "failed"
      metadata.error = `report generation failed: ${error.message}`
      save()
      throw error
    } finally {
      try { rmSync(data, { recursive: true, force: true }) }
      finally {
        process.removeListener("SIGINT", interrupt)
        process.removeListener("SIGTERM", interrupt)
      }
    }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1 })
}
