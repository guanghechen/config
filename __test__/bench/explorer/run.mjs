import { spawn, spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import { appendFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs"
import { arch, cpus, platform, release, tmpdir, totalmem } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { parseArgs } from "node:util"

import { analyze } from "./analyze.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const checkout = resolve(here, "../../..")
const cases = [
  { name: "mixed_200", entries: 200, directories: 20, branch: 0 },
  { name: "flat_1000", entries: 1000, directories: 0, branch: 0 },
  { name: "flat_10000", entries: 10000, directories: 0, branch: 0 },
  {
    name: "branch_1000_plus_9000",
    entries: 9000,
    directories: 0,
    branch: 1000,
  },
  { name: "flat_50000", entries: 50000, directories: 0, branch: 0 },
]

function capture(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    timeout: 30000,
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
  })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`${command}: ${result.stderr || result.stdout}`)
  return result.stdout.trim()
}

function hash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex")
}

function repository(path) {
  path = realpathSync(path)
  const native = join(path, "lua", process.platform === "win32" ? "yoz.dll" : "yoz.so")
  return {
    path,
    head: capture("git", ["rev-parse", "HEAD"], path),
    worktree: capture("git", ["status", "--porcelain=v1", "--untracked-files=normal"], path),
    native_module: native,
    native_module_sha256: hash(native),
  }
}

function measure(binary, args, timeout, signal) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(binary, args, {
      cwd: checkout,
      stdio: ["ignore", "pipe", "pipe"],
      detached: process.platform !== "win32",
    })
    let stdout = "",
      stderr = "",
      failure
    function stop(reason) {
      failure ??= new Error(reason)
      if (!child.pid) return
      if (process.platform === "win32") {
        spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], {
          stdio: "ignore",
        })
      } else {
        try {
          process.kill(-child.pid, "SIGKILL")
        } catch (error) {
          if (error.code !== "ESRCH") throw error
        }
      }
    }
    const timer = setTimeout(() => stop(`measurement exceeded ${timeout} ms`), timeout)
    const abort = () => stop("benchmark interrupted")
    signal.addEventListener("abort", abort, { once: true })
    child.stdout.on("data", (data) => {
      stdout += data
    })
    child.stderr.on("data", (data) => {
      stderr += data
    })
    child.on("error", (error) => {
      failure = error
    })
    child.on("close", (code) => {
      clearTimeout(timer)
      signal.removeEventListener("abort", abort)
      if (failure || code !== 0) {
        reject(new Error(`${failure?.message ?? `nvim exited ${code}`}\n${stderr}\n${stdout}`))
      } else {
        try {
          resolveRun(JSON.parse(stdout))
        } catch (error) {
          reject(new Error(`${error.message}\n${stdout}\n${stderr}`))
        }
      }
    })
    if (signal.aborted) abort()
  })
}

async function main() {
  const { values } = parseArgs({
    options: {
      current: { type: "string", default: checkout },
      baseline: { type: "string" },
      samples: { type: "string", default: "5" },
      repeats: { type: "string", default: "5" },
      case: { type: "string", multiple: true },
      mode: { type: "string", default: "tree" },
      output: { type: "string" },
      nvim: { type: "string", default: "nvim" },
      "timeout-ms": { type: "string", default: "180000" },
      help: { type: "boolean", short: "h" },
    },
  })
  if (values.help) {
    console.log(`Usage: node ${join(here, "run.mjs")} [options]
  --current PATH       Native Explorer checkout (default: this checkout)
  --baseline PATH      Optional legacy Explorer checkout (Tree comparison only)
  --samples N          Fresh processes per case/mode/implementation (default: 5)
  --repeats N          Warm fold/expand pairs and empty Git notifications (default: 5)
  --case NAME          Repeat to select cases (default: all)
  --mode tree|list|both (default: tree; fold/expand applies only to tree)
  --output PATH        New result directory (default: a fresh system temp directory)
  --nvim PATH          Neovim executable (default: nvim)
  --timeout-ms N       Whole-process timeout (default: 180000)
Cases: ${cases.map((item) => item.name).join(", ")}`)
    return
  }
  const samples = Number(values.samples),
    repeats = Number(values.repeats),
    timeout = Number(values["timeout-ms"])
  if (![samples, repeats].every((n) => Number.isInteger(n) && n >= 1 && n <= 100)) {
    throw new Error("samples and repeats must be integers from 1 through 100")
  }
  if (!Number.isInteger(timeout) || timeout < 1000) throw new Error("timeout-ms must be an integer >= 1000")
  if (!["tree", "list", "both"].includes(values.mode)) throw new Error("mode must be tree, list or both")
  const selected = values.case ?? cases.map((item) => item.name)
  for (const name of selected) {
    if (!cases.some((item) => item.name === name)) throw new Error(`unknown case: ${name}`)
  }
  const scenarios = cases.filter((item) => selected.includes(item.name))
  const modes = values.mode === "both" ? ["tree", "list"] : [values.mode]
  const repositories = { native: repository(values.current) }
  if (values.baseline) repositories.legacy = repository(values.baseline)
  const metadata = {
    schema_version: 1,
    started_at: new Date().toISOString(),
    status: "running",
    host: {
      platform: platform(),
      release: release(),
      arch: arch(),
      cpu: cpus()[0]?.model,
      memory_bytes: totalmem(),
    },
    nvim: capture(values.nvim, ["--version"], checkout).split("\n").slice(0, 3),
    repositories,
    samples,
    repeats,
    cases: scenarios,
    modes,
    harness_sha256: Object.fromEntries(
      ["run.mjs", "analyze.mjs", "runtime.lua", "measure.lua", "../../support/ui.lua", "../../support/ui_grid.lua"].map(
        (name) => [name, hash(join(here, name))],
      ),
    ),
    conditions: {
      ui: "110x40; Explorer width 44; rosepine-main; compress=false; show_hidden=true",
      fixture: "shared empty .lua files; filesystem caches warmed by creation; alternating A/B and B/A",
      process: "fresh embedded -u NONE -i NONE -n Neovim; modules/theme preloaded; no plugin startup or LSP",
      git: "collection disabled; empty_git_notification is an unchanged empty status notification, not a Git query",
      visible_ms: "operation start to parent observing matching content/cursor in a UI flush; excludes terminal/GPU",
      ready_ms:
        "complete row count and idle renderer; legacy includes offscreen deferred icons; native includes viewport decorations",
      timer: "maximum observed gap of a nominal 2 ms scheduled timer during each operation",
      memory:
        "natural GC while timing; full GC before snapshots; RSS, Lua heap and native accounting overlap and are not additive",
      statistics:
        "within-process medians, then distribution across independent processes; no p95 below 20 independent runs",
      list: "native only; the legacy viewtype flag does not recursively project directories and is not comparable",
    },
  }
  const output = values.output ? resolve(values.output) : mkdtempSync(join(tmpdir(), "explorer-bench-"))
  if (values.output) mkdirSync(output)
  const data = mkdtempSync(join(tmpdir(), "explorer-bench-data-"))
  const results = []
  const controller = new AbortController()
  const interrupt = () => controller.abort()
  process.on("SIGINT", interrupt)
  process.on("SIGTERM", interrupt)
  console.log(`Results: ${output}`)
  const saveMetadata = () => writeFileSync(join(output, "metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`)
  try {
    saveMetadata()
    for (const scenario of scenarios) {
      const folder = join(data, scenario.name)
      mkdirSync(folder)
      for (let i = 0; i < scenario.directories; i++) mkdirSync(join(folder, `directory-${String(i).padStart(3, "0")}`))
      for (let i = 0; i < scenario.entries - scenario.directories; i++) {
        writeFileSync(join(folder, `file-${String(i).padStart(5, "0")}.lua`), "", { flag: "wx" })
      }
      if (scenario.branch) {
        mkdirSync(join(folder, "a-branch"))
        for (let i = 0; i < scenario.branch; i++) {
          writeFileSync(join(folder, "a-branch", `inside-${String(i).padStart(5, "0")}.lua`), "", { flag: "wx" })
        }
      }
      for (const mode of modes) {
        for (let trial = 1; trial <= samples; trial++) {
          const order =
            repositories.legacy && mode === "tree"
              ? trial % 2
                ? ["legacy", "native"]
                : ["native", "legacy"]
              : ["native"]
          for (const implementation of order) {
            if (controller.signal.aborted) throw new Error("benchmark interrupted")
            const started = performance.now()
            const result = await measure(
              values.nvim,
              [
                "-l",
                join(here, "measure.lua"),
                repositories[implementation].path,
                folder,
                implementation,
                String(scenario.entries),
                String(scenario.branch),
                String(repeats),
                mode,
              ],
              timeout,
              controller.signal,
            )
            Object.assign(result, {
              case: scenario.name,
              trial,
              elapsed_seconds: (performance.now() - started) / 1000,
            })
            results.push(result)
            appendFileSync(join(output, "results.jsonl"), `${JSON.stringify(result)}\n`)
            console.log(
              JSON.stringify({
                case: scenario.name,
                mode,
                implementation,
                trial,
                open_visible_ms: result.operations[0].visible_ms,
                open_ready_ms: result.operations[0].ready_ms,
              }),
            )
          }
        }
      }
      rmSync(folder, { recursive: true })
    }
    metadata.status = "complete"
    metadata.completed_runs = results.length
    saveMetadata()
    analyze(output)
  } catch (error) {
    metadata.status = "failed"
    metadata.error = error.message
    throw error
  } finally {
    metadata.finished_at = new Date().toISOString()
    metadata.completed_runs = results.length
    try {
      saveMetadata()
    } finally {
      rmSync(data, { recursive: true, force: true })
      process.removeListener("SIGINT", interrupt)
      process.removeListener("SIGTERM", interrupt)
    }
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
})
