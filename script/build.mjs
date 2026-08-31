import { spawnSync } from "node:child_process"
import { randomUUID } from "node:crypto"
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  statSync,
} from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const RED = "\x1b[0;31m"
const GREEN = "\x1b[0;32m"
const BLUE = "\x1b[0;34m"
const CYAN = "\x1b[0;36m"
const RESET = "\x1b[0m"

export function getPlatformBuild(platform) {
  switch (platform) {
    case "darwin":
      return {
        source: "libyoz.dylib",
        lua: "yoz.so",
        bin: "osx.yoz.so",
        codesign: true,
      }
    case "linux":
      return {
        source: "libyoz.so",
        lua: "yoz.so",
        bin: "nix.yoz.so",
        codesign: false,
      }
    case "win32":
      return {
        source: "yoz.dll",
        lua: "yoz.dll",
        bin: "win.yoz.dll",
        codesign: false,
      }
    default:
      throw new Error(`unsupported platform: ${platform}`)
  }
}

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

function parseForce(args) {
  const invalid = args.find((arg) => arg !== "--force" && arg !== "-f")
  if (invalid) {
    throw new Error(`unknown option: ${invalid}\nusage: node script/build.mjs [--force|-f]`)
  }
  return args.length > 0
}

export function replaceFileIfChanged(source, destination) {
  if (
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

function findCaseInsensitive(dirpath, filename) {
  const matched = readdirSync(dirpath).find((entry) => entry.toLowerCase() === filename.toLowerCase())
  return matched ? join(dirpath, matched) : null
}

export function findWindowsSdkLibraries(root) {
  const versions = readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((left, right) => right.localeCompare(left, undefined, { numeric: true }))

  for (const version of versions) {
    const libDir = join(root, version, "um", "x64")
    if (!existsSync(libDir)) continue

    const kernel32 = findCaseInsensitive(libDir, "kernel32.lib")
    const user32 = findCaseInsensitive(libDir, "user32.lib")
    if (kernel32 && user32) return { kernel32, user32, version }
  }
  throw new Error(`Windows SDK x64 import libraries not found under: ${root}`)
}

export function isWslRuntime(env, kernelRelease) {
  const release = kernelRelease.toLowerCase()
  return Boolean(env.WSL_INTEROP || env.WSL_DISTRO_NAME || release.includes("microsoft") || release.includes("wsl"))
}

function readKernelRelease() {
  try {
    return readFileSync("/proc/sys/kernel/osrelease", "utf8")
  } catch {
    return ""
  }
}

function buildWslImHelper(rustDir, targetDir, stagedBin) {
  const source = join(rustDir, "im", "src", "bin", "yoz-im.rs")
  const buildDir = join(targetDir, "release", "yoz-im")
  const object = join(buildDir, "yoz-im.obj")
  const executable = join(buildDir, "wsl.yoz-im.exe")
  mkdirSync(buildDir, { recursive: true })

  const programFilesX86 = capture("wslpath", ["-u", "C:\\Program Files (x86)"], rustDir)
  const sdk = findWindowsSdkLibraries(join(programFilesX86, "Windows Kits", "10", "Lib"))
  const sysroot = capture("rustc", ["--print", "sysroot"], rustDir)
  const host = capture("rustc", ["-vV"], rustDir)
    .split("\n")
    .find((line) => line.startsWith("host: "))
    ?.slice("host: ".length)
  if (!host) throw new Error("rustc host triple is unavailable")
  const linker = join(sysroot, "lib", "rustlib", host, "bin", "rust-lld")
  if (!existsSync(linker)) throw new Error(`Rust linker not found: ${linker}`)

  run(
    "rustc",
    [
      source,
      "--crate-name",
      "yoz_im_helper",
      "--target",
      "x86_64-pc-windows-gnu",
      "--emit=obj",
      "-D",
      "warnings",
      "-C",
      "panic=abort",
      "-C",
      "opt-level=3",
      "-o",
      object,
    ],
    rustDir,
  )
  run(
    linker,
    [
      "-flavor",
      "link",
      "/entry:mainCRTStartup",
      "/subsystem:console",
      "/nodefaultlib",
      "/opt:ref",
      "/opt:icf",
      `/out:${executable}`,
      object,
      sdk.kernel32,
      sdk.user32,
    ],
    rustDir,
  )

  const smoke = spawnSync(executable, ["invalid"], { encoding: "utf8" })
  if (smoke.error) throw smoke.error
  if (smoke.status !== 1 || !smoke.stderr.includes("Expected one decimal input locale")) {
    throw new Error(`WSL IM bridge smoke test failed with status ${smoke.status ?? "unknown"}`)
  }

  mkdirSync(dirname(stagedBin), { recursive: true })
  copyFileSync(executable, stagedBin)
  console.log(`${GREEN}[neovim im] ✓ built with Windows SDK ${sdk.version}${RESET}`)
}

function main() {
  const force = parseForce(process.argv.slice(2))
  const build = getPlatformBuild(process.platform)
  const rustDir = resolve(dirname(fileURLToPath(import.meta.url)), "..", "rust")
  const packageDir = join(rustDir, "yoz")
  const targetDir = join(rustDir, "target")
  const luaDir = join(rustDir, "..", "lua")
  const binDir = join(rustDir, "..", "bin")
  const source = join(targetDir, "release", build.source)
  const stagedLua = join(targetDir, "deploy", "lua", build.lua)
  const stagedBin = join(targetDir, "deploy", "bin", build.bin)
  const wslImStagedBin = join(targetDir, "deploy", "bin", "wsl.yoz-im.exe")
  const luaOutput = join(luaDir, build.lua)
  const binOutput = join(binDir, build.bin)
  const wslImBinOutput = join(binDir, "wsl.yoz-im.exe")
  const isWslBuild = process.platform === "linux" && isWslRuntime(process.env, readKernelRelease())

  if (!existsSync(packageDir)) throw new Error(`package not found: ${packageDir}`)

  mkdirSync(luaDir, { recursive: true })
  mkdirSync(binDir, { recursive: true })

  if (force) rmSync(targetDir, { recursive: true, force: true })

  console.log(`${CYAN}[neovim yoz] compiling...${RESET}`)
  run("cargo", ["build", "--release", "--quiet"], packageDir)
  mkdirSync(dirname(stagedLua), { recursive: true })
  mkdirSync(dirname(stagedBin), { recursive: true })
  copyFileSync(source, stagedLua)
  copyFileSync(source, stagedBin)

  if (build.codesign) {
    run("codesign", ["--force", "--sign", "-", stagedLua], rustDir)
    run("codesign", ["--force", "--sign", "-", stagedBin], rustDir)
  }

  if (isWslBuild) {
    buildWslImHelper(rustDir, targetDir, wslImStagedBin)
  }

  if (isWslBuild) {
    replaceFileIfChanged(wslImStagedBin, wslImBinOutput)
  }
  replaceFileIfChanged(stagedLua, luaOutput)
  replaceFileIfChanged(stagedBin, binOutput)

  console.log(`${GREEN}[neovim yoz] ✓ built${RESET}`)
  console.log(`${BLUE}[neovim build] done${RESET}`)
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) {
  try {
    main()
  } catch (error) {
    console.error(`${RED}[neovim build] error: ${error.message}${RESET}`)
    process.exitCode = error.exitCode ?? 1
  }
}
