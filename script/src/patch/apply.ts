import { readFileSync, writeFileSync } from "node:fs"
import * as env from "../env"
import { getCliPath, getCliVersion } from "./util"
import type { IApplyOptions, IMatch, IPatch } from "./types"

function findMatches(content: string, search: string | RegExp): IMatch[] {
  const matches: IMatch[] = []

  if (typeof search === "string") {
    let index = 0
    while ((index = content.indexOf(search, index)) !== -1) {
      matches.push({
        matched_text: search,
        matched_groups: [],
        offset_start: index,
        offset_end: index + search.length,
      })
      index += search.length
    }
  } else {
    const regex = new RegExp(search.source, search.flags.replace("g", "") + "g")
    let match: RegExpExecArray | null
    while ((match = regex.exec(content)) !== null) {
      matches.push({
        matched_text: match[0],
        matched_groups: match.slice(1),
        offset_start: match.index,
        offset_end: match.index + match[0].length,
      })
    }
  }

  return matches
}

function applyPatch(content: string, patch: IPatch): string | null {
  if (patch.verify(content)) return null

  const matches = findMatches(content, patch.search)
  if (matches.length === 0) return null

  return patch.replace(content, matches)
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
    const label = `${patch.name}@${patch.version}`

    if (patch.version !== cliVersion) {
      if (!stopOnFirst) console.log(`[${label}] Version mismatch (current: ${cliVersion}), skipping`)
      continue
    }

    const result = applyPatch(content, patch)

    if (result === null) {
      if (patch.verify(content)) {
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
      const versionMatched = applicablePatches.some((p) => p.version === cliVersion)
      console.error(versionMatched ? "Pattern not found" : `No patch available for version ${cliVersion}`)
      console.error("Supported versions:")
      applicablePatches.forEach((p) => console.error(`  - ${p.version}`))
      process.exit(1)
    }
    console.log("\nNothing to patch")
    process.exit(0)
  }

  writeFileSync(cliPath, content)

  const verifyContent = readFileSync(cliPath, "utf-8")
  const failed = applicablePatches.filter((p) => p.version === cliVersion && !p.verify(verifyContent))

  if (failed.length === 0) {
    console.log(`\nPatched ${patchedCount} location(s) successfully`)
  } else {
    console.error("\nPatch verification failed:")
    failed.forEach((p) => console.error(`  - ${p.name}`))
    process.exit(1)
  }
}
