// Run with: node script/luals-check.mjs
// Repository LuaLS baseline: the pinned lua-language-server must report no Warning or Error.
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, relative, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { masonBin, resolveNeovim, run } from "./tooling.mjs"

// Diagnostics differ between LuaLS releases; bump only together with a clean re-check.
export const LUALS_VERSION = "3.19.1"

const SEVERITY = { 1: "Error", 2: "Warning" }

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, "..")

export function checkVersion(output) {
  const version = output.trim()
  if (version !== LUALS_VERSION) {
    throw new Error(
      `lua-language-server ${version || "(unknown)"} does not match the pinned ${LUALS_VERSION}; ` +
        `run :MasonInstall lua-language-server@${LUALS_VERSION}, or bump LUALS_VERSION after a clean re-check`,
    )
  }
  return version
}

// Tracked and unignored files only, so ignored checkout copies cannot add diagnostics.
function listInputs(cwd) {
  const args = ["ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.lua"]
  const { stdout } = run("git", args, { cwd })
  const filepaths = stdout.split("\0").filter((filepath) => filepath && existsSync(join(cwd, filepath)))
  return [".luarc.json", ...filepaths]
}

function stageWorkspace(cwd, filepaths, workspace) {
  for (const filepath of filepaths) {
    const target = join(workspace, filepath)
    mkdirSync(dirname(target), { recursive: true })
    copyFileSync(join(cwd, filepath), target)
  }
}

// With --quiet a clean check prints nothing; any output is a crash, hang guard, or checker error whose
// partial report would otherwise pass.
export function checkSilent({ stdout, stderr }) {
  const output = `${stdout ?? ""}${stderr ?? ""}`.trim()
  if (output) throw new Error(`lua-language-server failed:\n${output}`)
}

export function collectDiagnostics(report, workspace) {
  const diagnostics = []
  for (const [uri, items] of Object.entries(Array.isArray(report) ? {} : report)) {
    const filepath = relative(workspace, fileURLToPath(uri))
    for (const item of items) {
      const severity = SEVERITY[item.severity]
      if (!severity) continue
      diagnostics.push({
        filepath,
        line: item.range.start.line + 1,
        col: item.range.start.character + 1,
        severity,
        code: item.code,
        message: item.message.split("\n")[0],
      })
    }
  }
  return diagnostics.sort((a, b) => a.filepath.localeCompare(b.filepath) || a.line - b.line || a.col - b.col)
}

export function formatDiagnostic({ filepath, line, col, severity, code, message }) {
  return `${filepath}:${line}:${col}: [${severity}] ${code}: ${message}`
}

function check() {
  const neovim = resolveNeovim()
  const bin = masonBin(neovim, "lua-language-server")
  if (!existsSync(bin)) throw new Error(`missing ${bin}; run :MasonInstall lua-language-server@${LUALS_VERSION}`)
  const version = checkVersion(run(bin, ["--version"]).stdout)

  const tempDir = realpathSync(mkdtempSync(join(tmpdir(), "nvim-luals-")))
  try {
    const workspace = join(tempDir, "workspace")
    const inputs = listInputs(rootDir)
    stageWorkspace(rootDir, inputs, workspace)
    const logpath = join(tempDir, "log")
    // .luarc.json expands $VIMRUNTIME in workspace.library; LLS_* variables would override the CLI setup.
    const env = Object.fromEntries(Object.entries(process.env).filter(([name]) => !name.startsWith("LLS_")))
    env.VIMRUNTIME = neovim.runtime
    // LuaLS exits 1 when it reports diagnostics; failures may exit 0, so output and the report decide.
    checkSilent(
      run(
        bin,
        [`--check=${workspace}`, "--checklevel=Warning", "--check_format=json", `--logpath=${logpath}`, "--quiet"],
        { env, statuses: [0, 1] },
      ),
    )
    const reportpath = join(logpath, "check.json")
    if (!existsSync(reportpath)) throw new Error(`lua-language-server wrote no report to ${reportpath}`)
    const diagnostics = collectDiagnostics(JSON.parse(readFileSync(reportpath, "utf8")), workspace)
    return { version, neovim, files: inputs.length - 1, diagnostics }
  } finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
}

function main() {
  const { version, neovim, files, diagnostics } = check()
  console.log(
    `[luals-check] lua-language-server ${version}, Neovim ${neovim.version} (VIMRUNTIME=${neovim.runtime}), ` +
      `staged ${files} Lua files`,
  )
  for (const diagnostic of diagnostics) console.error(formatDiagnostic(diagnostic))
  if (diagnostics.length > 0) {
    console.error(`[luals-check] ${diagnostics.length} Warning/Error diagnostic(s)`)
    process.exitCode = 1
  } else {
    console.log("[luals-check] no Warning or Error")
  }
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) {
  try {
    main()
  } catch (error) {
    console.error(`[luals-check] ${error.message}`)
    process.exitCode = 1
  }
}
