// Run with: node script/format-check.mjs
// Repository formatting: the pinned StyLua for Lua and rustfmt for Rust must both report no difference.
import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { masonBin, resolveNeovim, run } from "./tooling.mjs"

// StyLua releases change formatting; bump only together with a repository-wide `stylua .`.
export const STYLUA_VERSION = "2.5.2"

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, "..")

export function checkStyluaVersion(output) {
  const version = output.trim().replace(/^stylua\s+/, "")
  if (version !== STYLUA_VERSION) {
    throw new Error(
      `stylua ${version || "(unknown)"} does not match the pinned ${STYLUA_VERSION}; ` +
        `run :MasonInstall stylua@${STYLUA_VERSION}, or bump STYLUA_VERSION after a repository-wide \`stylua .\``,
    )
  }
  return version
}

function main() {
  const stylua = masonBin(resolveNeovim(), "stylua")
  if (!existsSync(stylua)) throw new Error(`missing ${stylua}; run :MasonInstall stylua@${STYLUA_VERSION}`)
  const version = checkStyluaVersion(run(stylua, ["--version"]).stdout)

  // Both tools print their own differences; .gitignore and .styluaignore limit StyLua to repository sources.
  const failures = []
  if (spawnSync(stylua, ["--check", "."], { cwd: rootDir, stdio: "inherit" }).status !== 0) failures.push("Lua")
  const rust = spawnSync("cargo", ["fmt", "--all", "--check"], { cwd: join(rootDir, "rust"), stdio: "inherit" })
  if (rust.status !== 0) failures.push("Rust")

  if (failures.length > 0) {
    console.error(`[format-check] ${failures.join(" and ")} formatting differs; run \`stylua .\` or \`cargo fmt --all\``)
    process.exitCode = 1
  } else {
    console.log(`[format-check] stylua ${version} and rustfmt report no difference`)
  }
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) {
  try {
    main()
  } catch (error) {
    console.error(`[format-check] ${error.message}`)
    process.exitCode = 1
  }
}
