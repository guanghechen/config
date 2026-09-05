// Run with: node script/healcheck.mjs
import { spawnSync } from "node:child_process"
import { readdirSync } from "node:fs"
import { devNull } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const RED = "\x1b[0;31m"
const GREEN = "\x1b[0;32m"
const BLUE = "\x1b[0;34m"
const CYAN = "\x1b[0;36m"
const RESET = "\x1b[0m"

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, "..")
const rustDir = join(rootDir, "rust")

const REQUIREMENTS = [
  { name: "fd", command: "fd" },
  { name: "fzf", command: "fzf" },
  { name: "lazygit", command: "lazygit" },
  { name: "rg", command: "rg" },
  { name: "git", command: "git" },
  { name: "node", command: process.execPath },
  { name: "nvim", command: "nvim" },
  { name: "cargo", command: "cargo" },
  { name: "rustc", command: "rustc" },
]

function getFailure(result) {
  if (result.error) return result.error.message
  if (result.status === 0) return null
  return result.signal ? `signal ${result.signal}` : `status ${result.status ?? "unknown"}`
}

function getGitCheckFailure(result) {
  const failure = getFailure(result)
  if (!failure) return null

  const stderr = result.stderr?.trim()
  if (stderr) return stderr

  const lines = (result.stdout ?? "").split(/\r?\n/)
  const diagnostics = lines.filter(
    (line, index) => line && !(line.startsWith("+") && /:\d+: /.test(lines[index - 1] ?? "")),
  )
  return diagnostics.join("\n") || failure
}

function runCommand(command, args, cwd, stdio = "inherit") {
  return getFailure(spawnSync(command, args, { cwd, stdio }))
}

function findUnavailableRequirements(requirements) {
  return requirements
    .filter(({ command }) => getFailure(spawnSync(command, ["--version"], { stdio: "ignore" })) !== null)
    .map(({ name }) => name)
}

function checkRequirements() {
  const unavailable = findUnavailableRequirements(REQUIREMENTS)
  return unavailable.length === 0 ? null : `unavailable: ${unavailable.join(", ")}`
}

function checkGitWhitespace(cwd) {
  const failures = []
  const tracked = spawnSync(
    "git",
    [
      "--no-optional-locks",
      "--no-pager",
      "diff",
      "--no-color",
      "--no-ext-diff",
      "--no-textconv",
      "--output-indicator-new=+",
      "--check",
      "HEAD",
      "--",
    ],
    { cwd, encoding: "utf8" },
  )
  const trackedFailure = getGitCheckFailure(tracked)
  if (trackedFailure) failures.push(`tracked changes: ${trackedFailure}`)

  const discovered = spawnSync("git", ["ls-files", "--others", "--exclude-standard", "-z"], {
    cwd,
    encoding: "utf8",
  })
  const discoveryFailure = getFailure(discovered)
  if (discoveryFailure) {
    failures.push(`untracked discovery: ${discoveryFailure}`)
    return failures.join("; ")
  }

  const filepaths = discovered.stdout.split("\0").filter(Boolean)
  for (const filepath of filepaths) {
    const result = spawnSync(
      "git",
      [
        "--no-pager",
        "diff",
        "--no-color",
        "--no-ext-diff",
        "--no-textconv",
        "--output-indicator-new=+",
        "--no-index",
        "--check",
        "--",
        devNull,
        filepath,
      ],
      { cwd, encoding: "utf8" },
    )

    const clean = result.status === 0 || (result.status === 1 && !result.stdout && !result.stderr)
    if (!clean) {
      failures.push(`${JSON.stringify(filepath)}: ${getGitCheckFailure(result) || "unexpected output"}`)
    }
  }

  return failures.length === 0 ? null : failures.join("; ")
}

function getChecks() {
  const nodeTestDir = join(rootDir, "__test__", "node")
  const nodeTests = readdirSync(nodeTestDir)
    .filter((filename) => filename.endsWith(".test.mjs"))
    .sort()
    .map((filename) => join(nodeTestDir, filename))

  return [
    {
      name: "Requirements",
      run: checkRequirements,
    },
    {
      name: "Git whitespace",
      run: () => checkGitWhitespace(rootDir),
    },
    {
      name: "Node tests",
      run: () => runCommand(process.execPath, ["--test", ...nodeTests], rootDir),
    },
    {
      name: "Lua tests",
      run: () => runCommand("nvim", ["-l", "__test__/run.lua"], rootDir),
    },
    {
      name: "Rust tests",
      run: () => runCommand("cargo", ["test", "--workspace", "--all-targets", "--quiet"], rustDir),
    },
  ]
}

function formatDuration(duration) {
  return duration < 1000 ? `${duration.toFixed(0)}ms` : `${(duration / 1000).toFixed(2)}s`
}

function runCheck(check) {
  console.log(`${CYAN}[neovim healcheck] ${check.name}${RESET}`)
  const startedAt = performance.now()
  const failure = check.run()
  const duration = formatDuration(performance.now() - startedAt)

  if (failure) {
    console.error(`${RED}[neovim healcheck] ✗ ${check.name}: ${failure} (${duration})${RESET}`)
    return false
  }

  console.log(`${GREEN}[neovim healcheck] ✓ ${check.name} (${duration})${RESET}`)
  return true
}

function main() {
  let failed = 0
  for (const check of getChecks()) {
    if (!runCheck(check)) failed += 1
  }

  if (failed > 0) {
    console.error(`${RED}[neovim healcheck] ${failed} check(s) failed${RESET}`)
    process.exitCode = 1
  } else {
    console.log(`${BLUE}[neovim healcheck] all checks passed${RESET}`)
  }
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) {
  main()
}
