// Runs the fuzzy matcher benchmark suite (levels rust, ffi, e2e) and writes a report.
import { spawn, spawnSync } from "node:child_process"
import { appendFileSync, existsSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs"
import { arch, cpus, platform, release, tmpdir, totalmem } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { parseArgs } from "node:util"

import { ensureCorpora, verifyCorpora } from "./fuzzy-corpus.mjs"
import { analyze } from "./fuzzy-report.mjs"
import { fileHash, inspectArtifact, nativeInputs, runtimeInputs } from "./provenance.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const checkout = resolve(here, "../..")
const resultsRoot = join(checkout, "__test__/bench/results/fuzzy")
const nativeName = process.platform === "win32" ? "yoz.dll" : "yoz.so"

export const LEVELS = ["rust", "ffi", "e2e"]

/** L1 invocations; larger corpora keep every n-th typing sequence and fewer passes, as the old matchers are slow there. */
export const rustPlans = [
  { corpora: ["repo", "runtime", "plugins", "synthetic-10k", "labels", "unicode"], stride: 1 },
  { corpora: ["synthetic-100k", "labels-100k"], stride: 2, samples: 3 },
  { corpora: ["synthetic-1m"], stride: 8, samples: 1 },
]
export const ffiPlans = [
  { corpus: "repo", stride: 1 }, { corpus: "synthetic-10k", stride: 1 }, { corpus: "labels", stride: 1 }, { corpus: "unicode", stride: 1 },
  { corpus: "synthetic-100k", stride: 2, samples: 3 }, { corpus: "labels-100k", stride: 2, samples: 3 },
]

/** L3 cases; `pace` is the delay between keystrokes against the picker's 64 ms match debounce. */
export const cases = [
  { name: "files_repo_tree", scenario: "files", corpus: "repo", mode: "tree", pace: 120 },
  { name: "files_repo_list", scenario: "files", corpus: "repo", mode: "list", pace: 120 },
  { name: "files_10k_tree", scenario: "files", corpus: "synthetic-10k", mode: "tree", pace: 120 },
  { name: "files_10k_list", scenario: "files", corpus: "synthetic-10k", mode: "list", pace: 120 },
  { name: "files_10k_burst", scenario: "files", corpus: "synthetic-10k", mode: "tree", pace: 40 },
  { name: "files_100k_tree", scenario: "files", corpus: "synthetic-100k", mode: "tree", pace: 120 },
  { name: "files_unicode_list", scenario: "files", corpus: "unicode", mode: "list", pace: 120 },
  { name: "list_labels", scenario: "list", corpus: "labels", mode: "list", pace: 120 },
  { name: "list_labels_burst", scenario: "list", corpus: "labels", mode: "list", pace: 40 },
  { name: "list_100k", scenario: "list", corpus: "labels-100k", mode: "list", pace: 120 },
]

function capture(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 1 << 26, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" }, ...options })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")}: ${result.stderr || result.stdout}`)
  return result.stdout.trim()
}

function host() {
  const sysctl = (name) => {
    const result = spawnSync("sysctl", ["-n", name], { encoding: "utf8" })
    return result.status === 0 ? Number(result.stdout.trim()) : undefined
  }
  const power = spawnSync("pmset", ["-g", "batt"], { encoding: "utf8" })
  return {
    platform: platform(), release: release(), arch: arch(), cpu: cpus()[0]?.model, logical_cpus: cpus().length, memory_bytes: totalmem(),
    performance_cores: sysctl("hw.perflevel0.physicalcpu"), efficiency_cores: sysctl("hw.perflevel1.physicalcpu"),
    power: power.status === 0 ? power.stdout.match(/'([^']+)'/)?.[1] : undefined,
  }
}

/** Extracts a committed revision without touching the repository's worktrees, index or refs. */
function extract(revision) {
  const commit = capture("git", ["-C", checkout, "rev-parse", "--verify", "--end-of-options", `${revision}^{commit}`])
  const directory = join(resultsRoot, "checkouts", commit.slice(0, 12))
  const marker = join(directory, ".fuzzy-bench-source.json")
  if (!existsSync(marker)) {
    // A directory without the marker is an interrupted extraction.
    rmSync(directory, { recursive: true, force: true })
    mkdirSync(directory, { recursive: true })
    const archive = spawnSync("git", ["-C", checkout, "archive", "--format=tar", commit], { maxBuffer: 1 << 30, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" } })
    if (archive.status !== 0) throw new Error(`git archive failed: ${archive.stderr}`)
    // File contents are the input; restoring archive metadata can fail on macOS and is not needed.
    const untar = spawnSync("tar", ["-x", "-m", "--no-same-permissions", "--no-xattrs", "--no-acls", "--no-fflags", "-C", directory], { input: archive.stdout })
    if (untar.status !== 0) throw new Error(`tar failed: ${untar.stderr}`)
    const tree = capture("git", ["-C", checkout, "rev-parse", "--verify", "--end-of-options", `${commit}^{tree}`])
    writeFileSync(marker, `${JSON.stringify({ revision, commit, tree })}\n`)
  }
  return directory
}

function sourceOf(path) {
  const marker = join(path, ".fuzzy-bench-source.json")
  if (existsSync(marker)) return { kind: "archive", ...JSON.parse(readFileSync(marker, "utf8")) }
  return {
    kind: "checkout",
    commit: capture("git", ["-C", path, "rev-parse", "--verify", "--end-of-options", "HEAD^{commit}"]),
    tree: capture("git", ["-C", path, "rev-parse", "--verify", "--end-of-options", "HEAD^{tree}"]),
    status: capture("git", ["-C", path, "--no-optional-locks", "status", "--porcelain=v1", "--untracked-files=all"]).split("\n").filter(Boolean),
  }
}

function snapshot(implementation) {
  return {
    native: nativeInputs(implementation.path).sha256,
    runtime: runtimeInputs(implementation.path).sha256,
    library: fileHash(implementation.library),
  }
}

function execute(command, args, timeout, signal, env = {}) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(command, args, { cwd: checkout, stdio: ["ignore", "pipe", "pipe"], detached: true, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0", ...env } })
    let stdout = "", stderr = "", failure
    const stop = (reason) => {
      failure ??= new Error(reason)
      try { process.kill(-child.pid, "SIGKILL") } catch (error) { if (error.code !== "ESRCH") throw error }
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
      if (failure || code !== 0) reject(Object.assign(new Error(failure?.message ?? `${command} exited ${code}`), { stdout, stderr }))
      else resolveRun({ stdout, stderr })
    })
  })
}

/** Writes the corpus as empty files under the temporary directory, outside every Git repository. */
function materialize(corpusDir, name, manifest) {
  const entry = manifest.corpora[name]
  const root = join(tmpdir(), "fuzzy-bench-trees", `${name}-${entry.sha256.slice(0, 12)}`)
  const marker = join(root, ".fuzzy-bench-complete")
  if (!existsSync(marker)) {
    const paths = readFileSync(join(corpusDir, `${name}.txt`), "utf8").split("\n").filter(Boolean)
    const directories = new Set(paths.map((path) => dirname(path)))
    for (const directory of directories) mkdirSync(join(root, directory), { recursive: true })
    for (const path of paths) writeFileSync(join(root, path), "")
    writeFileSync(marker, `${entry.sha256}\n`)
  }
  return root
}

async function main() {
  const { values } = parseArgs({ options: {
    level: { type: "string", multiple: true }, case: { type: "string", multiple: true },
    current: { type: "string", default: checkout }, baseline: { type: "string" }, "baseline-rev": { type: "string" },
    build: { type: "boolean" }, native: { type: "string" }, probes: { type: "string" },
    "corpus-dir": { type: "string", default: join(resultsRoot, "corpus") },
    samples: { type: "string", default: "5" }, runs: { type: "string", default: "3" }, sequences: { type: "string", default: "8" },
    output: { type: "string" }, nvim: { type: "string", default: "nvim" }, "timeout-ms": { type: "string", default: "900000" },
    help: { type: "boolean", short: "h" },
  } })
  if (values.help) {
    console.log(`Usage: node ${fileURLToPath(import.meta.url)} [options]
  --level rust|ffi|e2e   Repeat to select levels (default: all)
  --case NAME            Repeat to select L3 cases (default: all)
  --current PATH         Measured checkout (default: this checkout)
  --baseline PATH        Baseline checkout for L3 A/B runs
  --baseline-rev REV     Baseline commit, extracted with git archive (read-only for the repository)
  --build                Build source-bound native libraries into ${join(resultsRoot, "native")}
  --native PATH          Native library for the current checkout (default: current/lua/${nativeName})
  --probes A,B           L1 matchers to run (default: all)
  --corpus-dir DIR       Corpus cache (default: ${join(resultsRoot, "corpus")})
  --samples N            Timed passes per process for L1/L2 (default: 5)
  --runs N               Independent processes per case and implementation (default: 3)
  --sequences N          Typing sequences per L3 process (default: 8)
  --output DIR           Result directory (default: ${join(resultsRoot, "<timestamp>")})
L3 cases: ${cases.map((item) => item.name).join(", ")}`)
    return
  }
  const levels = values.level ?? LEVELS
  for (const level of levels) if (!LEVELS.includes(level)) throw new Error(`unknown level: ${level}`)
  const selected = values.case ?? cases.map((item) => item.name)
  for (const name of selected) if (!cases.some((item) => item.name === name)) throw new Error(`unknown case: ${name}`)
  const samples = Number(values.samples), runs = Number(values.runs), sequences = Number(values.sequences), timeout = Number(values["timeout-ms"])
  if (![samples, runs, sequences].every((value) => Number.isInteger(value) && value >= 1 && value <= 200)) throw new Error("samples, runs and sequences must be integers from 1 through 200")
  if (values.baseline && values["baseline-rev"]) throw new Error("use --baseline or --baseline-rev, not both")

  const output = resolve(values.output ?? join(resultsRoot, new Date().toISOString().replaceAll(":", "-")))
  mkdirSync(join(output, "logs"), { recursive: true })
  const corpusDir = resolve(values["corpus-dir"])
  const e2eCases = levels.includes("e2e") ? cases.filter((item) => selected.includes(item.name)) : []
  const names = [...new Set([...(levels.includes("rust") ? rustPlans.flatMap((plan) => plan.corpora) : []), ...(levels.includes("ffi") ? ffiPlans.map((plan) => plan.corpus) : []), ...e2eCases.map((item) => item.corpus)])]
  ensureCorpora(corpusDir, { names, nvim: values.nvim })
  const manifest = verifyCorpora(corpusDir, names)

  const locations = { current: realpathSync(values.current) }
  if (values.baseline) locations.baseline = realpathSync(values.baseline)
  if (values["baseline-rev"]) locations.baseline = extract(values["baseline-rev"])
  const implementations = {}
  const controller = new AbortController()
  for (const [name, path] of Object.entries(locations)) {
    let library = name === "current" && values.native ? realpathSync(values.native) : join(path, "lua", nativeName)
    let provenance = existsSync(library) ? inspectArtifact(path, library) : { status: "missing" }
    if (values.build && provenance.status !== "verified") {
      const source = sourceOf(path)
      const buildRoot = join(resultsRoot, "native", name === "current" ? "current" : source.commit.slice(0, 12))
      library = join(buildRoot, "lua", nativeName)
      if (!existsSync(library) || inspectArtifact(path, library).status !== "verified") {
        console.log(`Building ${name} native library`)
        // build.mjs refuses an existing output; a stale build here belongs to other sources.
        rmSync(buildRoot, { recursive: true, force: true })
        const result = await execute(process.execPath, [join(checkout, "script/build.mjs"), "--root", path, "--output", buildRoot, "--offline"], Math.max(timeout, 1800000), controller.signal)
          .catch((error) => { throw new Error(`${error.message}\n${error.stderr?.slice(-2000) ?? ""}`) })
        writeFileSync(join(output, "logs", `build-${name}.stderr`), result.stderr)
      }
      provenance = inspectArtifact(path, library)
    }
    if (provenance.status !== "verified") throw new Error(`${name} native library is ${provenance.status} for its sources (${library}); use --build`)
    implementations[name] = { name, path, library, provenance, source: sourceOf(path), runtime: runtimeInputs(path).sha256 }
  }

  const metadata = {
    schema_version: 1, started_at: new Date().toISOString(), status: "running", host: host(),
    nvim: capture(values.nvim, ["--version"]).split("\n").slice(0, 3), levels, cases: e2eCases, samples, runs, sequences,
    corpora: Object.fromEntries(names.map((name) => [name, manifest.corpora[name]])),
    implementations: Object.fromEntries(Object.entries(implementations).map(([name, item]) => [name, { path: item.path, library: item.library, source: item.source, runtime_sha256: item.runtime, native_sha256: item.provenance.source.sha256, artifact_sha256: item.provenance.artifact_sha256 }])),
    harness_sha256: Object.fromEntries(["fuzzy.mjs", "fuzzy-corpus.mjs", "fuzzy-report.mjs"].map((name) => [`script/benchmark/${name}`, fileHash(join(here, name))]).concat(["ffi.lua", "e2e.lua", "probes.lua", "init.lua"].map((name) => [`__test__/bench/fuzzy/${name}`, fileHash(join(checkout, "__test__/bench/fuzzy", name))]))),
    conditions: {
      order: "fresh processes; one benchmark at a time; L3 implementations alternate A/B and B/A by run",
      rust: "L1 compares matchers inside one release test process: one untimed warm pass, then samples with the probe order rotated per sample; per-query medians",
      ffi: "L2 loads one native library into headless nvim; full GC before and GC stopped during each timed keystroke to count Lua allocation; the first query of the process is reported as cold",
      e2e: "L3 runs the full config of each checkout in an embedded UI (120x40) with workspace, editor and frecency state in a fresh directory; frecency seeded for 2% of file items with recency spread over every bucket; file corpora are empty files under the temporary directory, outside Git; completion is disabled in picker finders because its popup diverts TextChangedI; keystrokes enter through nvim_input; visibility is a parent-observed flush whose header shows the published total",
      corpora: "generated once and cached with SHA-256; regenerating with --force changes the inputs",
    },
    commands: [],
  }
  const save = () => writeFileSync(join(output, "metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`)
  const inputs = () => JSON.stringify(Object.fromEntries(Object.values(implementations).map((item) => [item.name, snapshot(item)])))
  const expected = inputs()
  const check = () => {
    verifyCorpora(corpusDir, names)
    if (inputs() !== expected) throw new Error("input validation failed: measured sources or native libraries changed during the run")
  }
  const record = (result, extra) => appendFileSync(join(output, "results.jsonl"), `${JSON.stringify({ ...result, ...extra })}\n`)
  const interrupt = () => controller.abort()
  process.on("SIGINT", interrupt)
  process.on("SIGTERM", interrupt)
  console.log(`Results: ${output}`)
  try {
    save()
    const current = implementations.current
    if (levels.includes("rust")) {
      for (let run = 1; run <= runs; run++) {
        for (const plan of rustPlans) {
          check()
          const file = join(output, `rust-${run}-${plan.corpora[0]}.jsonl`)
          const args = ["test", "--manifest-path", join(current.path, "rust/Cargo.toml"), "-p", "yoz", "--release", "--offline", "--locked", "--lib", "fuzzy::perf_tests", "--", "--ignored", "--nocapture", "--test-threads=1"]
          const env = { YOZ_FUZZY_BENCH_CORPUS: corpusDir, YOZ_FUZZY_BENCH_CORPORA: plan.corpora.join(","), YOZ_FUZZY_BENCH_SAMPLES: String(plan.samples ?? samples), YOZ_FUZZY_BENCH_SEQUENCES: String(plan.stride), YOZ_FUZZY_BENCH_OUT: file, ...(values.probes ? { YOZ_FUZZY_BENCH_PROBES: values.probes } : {}) }
          metadata.commands.push({ level: "rust", run, command: "cargo", args, env })
          console.log(`rust ${run}/${runs} ${plan.corpora.join(",")}`)
          const result = await execute("cargo", args, timeout, controller.signal, env)
          writeFileSync(join(output, "logs", `rust-${run}-${plan.corpora[0]}.stderr`), result.stderr)
          for (const line of readFileSync(file, "utf8").split("\n").filter(Boolean)) record(JSON.parse(line), { implementation: "current", run })
        }
      }
    }
    if (levels.includes("ffi")) {
      for (let run = 1; run <= runs; run++) {
        for (const plan of ffiPlans) {
          check()
          const args = ["-l", join(checkout, "__test__/bench/fuzzy/ffi.lua"), current.path, corpusDir, plan.corpus, String(plan.samples ?? samples), current.library, String(plan.stride)]
          metadata.commands.push({ level: "ffi", run, command: values.nvim, args })
          console.log(`ffi ${run}/${runs} ${plan.corpus}`)
          const result = await execute(values.nvim, args, timeout, controller.signal)
          for (const line of result.stdout.split("\n").filter(Boolean)) record(JSON.parse(line), { implementation: "current", run })
        }
      }
    }
    const empty = join(output, "workspace")
    mkdirSync(empty, { recursive: true })
    for (const scenario of e2eCases) {
      const workspace = scenario.scenario === "files" ? materialize(corpusDir, scenario.corpus, manifest) : empty
      for (let run = 1; run <= runs; run++) {
        const order = Object.keys(implementations)
        if (run % 2 === 0) order.reverse()
        for (const name of order) {
          check()
          const implementation = implementations[name]
          const args = ["-l", join(checkout, "__test__/bench/fuzzy/e2e.lua"), implementation.path, corpusDir, scenario.corpus, workspace, scenario.scenario, scenario.mode, String(scenario.pace), String(sequences), implementation.library]
          metadata.commands.push({ level: "e2e", case: scenario.name, implementation: name, run, command: values.nvim, args })
          console.log(`e2e ${scenario.name} ${name} ${run}/${runs}`)
          try {
            const result = await execute(values.nvim, args, timeout, controller.signal)
            record(JSON.parse(result.stdout), { case: scenario.name, implementation: name, run })
          } catch (error) {
            writeFileSync(join(output, "logs", `e2e-${scenario.name}-${name}-${run}.stderr`), error.stderr ?? error.message)
            throw error
          }
        }
      }
    }
    check()
    metadata.status = "complete"
  } catch (error) {
    metadata.status = "failed"
    metadata.error = error.message
    console.error(error.message)
    process.exitCode = 1
  } finally {
    metadata.finished_at = new Date().toISOString()
    save()
    analyze(output)
    process.removeListener("SIGINT", interrupt)
    process.removeListener("SIGTERM", interrupt)
    console.log(`Report: ${join(output, "report.md")}`)
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1 })
}
