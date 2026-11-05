import { spawnSync } from "node:child_process"
import { createHash, randomUUID } from "node:crypto"
import {
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import { basename, dirname, join, relative, resolve, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { parseArgs } from "node:util"

const RED = "\x1b[0;31m"
const GREEN = "\x1b[0;32m"
const BLUE = "\x1b[0;34m"
const CYAN = "\x1b[0;36m"
const RESET = "\x1b[0m"

const RENDERER = "ghc-tmux-status"
const PACKAGE_DIR = "rust/ghc-tmux-status"
const PROTOCOL_FILE = "script/renderer-protocol"

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, stdio: "inherit" })

  if (result.error) throw result.error
  if (result.status === 0) return

  const error = new Error(`${command} exited with status ${result.status ?? "unknown"}`)
  error.exitCode = result.status ?? 1
  throw error
}

function capture(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" })

  if (result.error) throw result.error
  if (result.status === 0) return result.stdout.trim()

  const details = result.stderr.trim() || result.stdout.trim()
  const error = new Error(
    `${command} exited with status ${result.status ?? "unknown"}${details ? `: ${details}` : ""}`,
  )
  error.exitCode = result.status ?? 1
  throw error
}

function fileHash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex")
}

// The renderer embeds the protocol file, so it is a build input beside the crate.
export function rendererInputs(root) {
  root = realpathSync(root)
  const excluded = `${PACKAGE_DIR}/target`
  const files = {}
  function visit(path) {
    const name = relative(root, path).split(sep).join("/")
    if (name === excluded || basename(path) === ".DS_Store") return
    const stat = lstatSync(path)
    if (stat.isSymbolicLink()) throw new Error(`build input must not be a symlink: ${name}`)
    if (stat.isDirectory()) {
      for (const entry of readdirSync(path).sort()) visit(join(path, entry))
    } else if (stat.isFile()) {
      files[name] = fileHash(path)
    }
  }
  visit(join(root, PACKAGE_DIR))
  visit(join(root, PROTOCOL_FILE))
  const ordered = Object.fromEntries(Object.entries(files).sort(([left], [right]) => (left < right ? -1 : 1)))
  const hash = createHash("sha256")
  for (const [name, value] of Object.entries(ordered)) hash.update(`${name}\0${value}\0`)
  return { sha256: hash.digest("hex"), files: ordered }
}

export function verifyRenderer(filepath, protocol) {
  const reported = capture(filepath, ["protocol"], dirname(filepath))
  if (reported !== protocol) {
    throw new Error(`${filepath} reports protocol ${JSON.stringify(reported)}, expected ${JSON.stringify(protocol)}`)
  }
}

export function replaceFileIfChanged(source, destination, { force = false } = {}) {
  if (
    !force &&
    existsSync(destination) &&
    statSync(source).size === statSync(destination).size &&
    readFileSync(source).equals(readFileSync(destination))
  ) {
    return false
  }

  const temporary = `${destination}.${randomUUID()}.tmp`
  try {
    copyFileSync(source, temporary)
    renameSync(temporary, destination)
  } finally {
    rmSync(temporary, { force: true })
  }
  return true
}

function writeBuildReceipt(path, source, build) {
  const receipt = {
    schema_version: 1,
    built_at: new Date().toISOString(),
    artifact_sha256: fileHash(path),
    source,
    build,
  }
  writeFileSync(`${path}.build.json`, `${JSON.stringify(receipt, null, 2)}\n`)
}

function main() {
  const { values } = parseArgs({ options: {
    force: { type: "boolean", short: "f" },
    root: { type: "string", default: resolve(dirname(fileURLToPath(import.meta.url)), "..") },
    output: { type: "string" },
    offline: { type: "boolean" },
  } })
  const checkout = resolve(values.root)
  const packageDir = join(checkout, PACKAGE_DIR)
  const output = values.output && resolve(values.output)
  if (output && existsSync(output)) throw new Error(`output directory already exists: ${output}`)
  const targetDir = output ? join(output, "target") : join(packageDir, "target")
  const binDir = output ? join(output, "bin") : join(checkout, "bin")
  const source = join(targetDir, "release", RENDERER)
  const staged = join(targetDir, "deploy", "bin", RENDERER)
  const binOutput = join(binDir, RENDERER)

  if (!existsSync(packageDir)) throw new Error(`package not found: ${packageDir}`)
  const protocol = readFileSync(join(checkout, PROTOCOL_FILE), "utf8").trim()
  const inputs = rendererInputs(checkout)
  const toolchain = {
    rustc: capture("rustc", ["-vV"], packageDir),
    cargo: capture("cargo", ["--version"], packageDir),
    platform: process.platform,
    arch: process.arch,
    profile: "release",
  }

  mkdirSync(binDir, { recursive: true })

  if (values.force) rmSync(targetDir, { recursive: true, force: true })

  console.log(`${CYAN}[tmux renderer] compiling${values.force ? " from a clean target" : ""}...${RESET}`)
  const cargoArgs = ["build", "--release", "--locked", "--quiet", "--target-dir", targetDir]
  if (values.offline) cargoArgs.push("--offline")
  run("cargo", cargoArgs, packageDir)
  mkdirSync(dirname(staged), { recursive: true })
  copyFileSync(source, staged)

  if (process.platform === "darwin") {
    run("codesign", ["--force", "--sign", "-", staged], packageDir)
  }

  verifyRenderer(staged, protocol)
  if (rendererInputs(checkout).sha256 !== inputs.sha256) throw new Error("renderer inputs changed during the build")

  // Scripts run the deployed path every few seconds; a rename keeps every
  // invocation on one complete binary, and running processes keep the old inode.
  // A clean build is usually byte-identical, so --force also skips the comparison.
  const deployed = replaceFileIfChanged(staged, binOutput, { force: values.force })
  writeBuildReceipt(binOutput, inputs, { ...toolchain, protocol, command: ["cargo", ...cargoArgs], source_root: checkout })

  console.log(`${GREEN}[tmux renderer] ✓ ${deployed ? "deployed" : "unchanged"}: ${binOutput}${RESET}`)
  // New invocations pick the binary up at once; cached status formats are only
  // re-rendered by the next lifecycle event, heartbeat, or config reload.
  console.log(`${BLUE}[tmux build] done${deployed && !output ? "; reload the tmux config to re-render now" : ""}${RESET}`)
}

// import.meta.url is the resolved path, so compare against the resolved argv entry.
if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main()
  } catch (error) {
    console.error(`${RED}[tmux build] error: ${error.message}${RESET}`)
    process.exitCode = error.exitCode ?? 1
  }
}
