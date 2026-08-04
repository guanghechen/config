import { spawnSync } from "node:child_process"
import { copyFileSync, existsSync, mkdirSync, rmSync } from "node:fs"
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

function parseForce(args) {
  const invalid = args.find((arg) => arg !== "--force" && arg !== "-f")
  if (invalid) {
    throw new Error(`unknown option: ${invalid}\nusage: node rust/script/build.mjs [--force|-f]`)
  }
  return args.length > 0
}

function main() {
  const force = parseForce(process.argv.slice(2))
  const build = getPlatformBuild(process.platform)
  const rustDir = resolve(dirname(fileURLToPath(import.meta.url)), "..")
  const packageDir = join(rustDir, "yoz")
  const targetDir = join(rustDir, "target")
  const luaDir = join(rustDir, "..", "lua")
  const binDir = join(rustDir, "..", "bin")
  const source = join(targetDir, "release", build.source)
  const stagedLua = join(targetDir, "deploy", "lua", build.lua)
  const stagedBin = join(targetDir, "deploy", "bin", build.bin)
  const luaOutput = join(luaDir, build.lua)
  const binOutput = join(binDir, build.bin)

  if (!existsSync(packageDir)) throw new Error(`package not found: ${packageDir}`)

  mkdirSync(luaDir, { recursive: true })
  mkdirSync(binDir, { recursive: true })

  if (!force && existsSync(luaOutput) && existsSync(binOutput)) {
    console.log(`${GREEN}[neovim yoz] ✓ cached${RESET}`)
    console.log(`${BLUE}[neovim build] done${RESET}`)
    return
  }

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

  copyFileSync(stagedLua, luaOutput)
  copyFileSync(stagedBin, binOutput)
  rmSync(targetDir, { recursive: true, force: true })

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
