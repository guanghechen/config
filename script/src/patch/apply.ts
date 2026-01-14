import { readFileSync, writeFileSync } from "node:fs"
import * as env from "../env"
import { getCliPath, getCliVersion } from "./util"
import type { IApplyOptions, IPatch } from "./types"

function applyPatch(content: string, patch: IPatch): string | null {
  if (content.includes(patch.replace)) return null

  if (typeof patch.search === "string") {
    if (!content.includes(patch.search)) return null
    return content.split(patch.search).join(patch.replace)
  }

  const regex = new RegExp(patch.search.source, patch.search.flags.replace("g", "") + "g")
  if (!regex.test(content)) return null
  return content.replace(regex, patch.replace)
}

export function applyPatches(options: IApplyOptions): void {
  const { patches, stopOnFirst = false } = options

  const cliPath = getCliPath()
  if (!cliPath) {
    console.error("Claude Code not found")
    process.exit(1)
  }

  let content = readFileSync(cliPath, "utf-8")
  const cliVersion = getCliVersion()

  console.log(`File: ${cliPath}`)
  console.log(`Version: ${cliVersion || "unknown"}\n`)

  const applicablePatches = patches.filter((p) => p.platform.includes(env.platform))
  let patchedCount = 0

  for (const patch of applicablePatches) {
    const label = patch.version ? `${patch.name}@${patch.version}` : patch.name

    if (patch.version && patch.version !== cliVersion) {
      if (!stopOnFirst) console.log(`[${label}] Version mismatch (current: ${cliVersion}), skipping`)
      continue
    }

    const result = applyPatch(content, patch)

    if (result === null) {
      if (content.includes(patch.replace)) {
        console.log(`[${label}] Already patched`)
        if (stopOnFirst) process.exit(0)
      } else if (!stopOnFirst) {
        console.log(`[${label}] Pattern not found, skipping`)
      }
      continue
    }

    console.log(`[${label}] Patched`)
    content = result
    patchedCount++

    if (stopOnFirst) break
  }

  if (patchedCount === 0) {
    if (stopOnFirst) {
      const versionMatched = applicablePatches.some((p) => !p.version || p.version === cliVersion)
      console.error(versionMatched ? "Pattern not found" : `No patch available for version ${cliVersion}`)
      console.error("Supported versions:")
      applicablePatches.forEach((p) => console.error(`  - ${p.version || "*"}`))
      process.exit(1)
    }
    console.log("\nNothing to patch")
    process.exit(0)
  }

  writeFileSync(cliPath, content)

  const verifyContent = readFileSync(cliPath, "utf-8")
  const failed = applicablePatches.filter(
    (p) => (!p.version || p.version === cliVersion) && !verifyContent.includes(p.replace),
  )

  if (failed.length === 0) {
    console.log(`\nPatched ${patchedCount} location(s) successfully`)
  } else {
    console.error("\nPatch verification failed:")
    failed.forEach((p) => console.error(`  - ${p.name}`))
    process.exit(1)
  }
}
