import { readFileSync, writeFileSync } from "node:fs"
import * as env from "../env"
import type { IPlatform } from "../env"
import { getCliPath } from "../util/cli-path"

export interface IMatchPosition {
  start: number
  end: number
  match: string
  groups?: string[]
}

export interface IPatch {
  name: string
  version?: string
  platform: IPlatform[]
  search: (text: string) => IMatchPosition[]
  replace: (text: string, matches: IMatchPosition[]) => string
  verify?: (text: string) => boolean
}

export interface IApplyOptions {
  patches: IPatch[]
  stopOnFirst?: boolean
  formatMatch?: (patch: IPatch, match: IMatchPosition) => string
}

function replaceMatches(
  text: string,
  matches: IMatchPosition[],
  replacer: (m: IMatchPosition) => string,
): string {
  let result = text
  for (let i = matches.length - 1; i >= 0; i--) {
    const m = matches[i]
    result = result.slice(0, m.start) + replacer(m) + result.slice(m.end)
  }
  return result
}

export function applyPatches(options: IApplyOptions): void {
  const { patches, stopOnFirst = false, formatMatch } = options

  const cliPath = getCliPath()
  if (!cliPath) {
    console.error("Claude Code not found")
    process.exit(1)
  }

  console.log(`File: ${cliPath}\n`)

  let content = readFileSync(cliPath, "utf-8")
  let patchedCount = 0

  const applicablePatches = patches.filter((p) => p.platform.includes(env.platform))
  const appliedPatches: IPatch[] = []

  for (const patch of applicablePatches) {
    const label = patch.version ? `${patch.name}@${patch.version}` : patch.name

    if (patch.verify?.(content)) {
      console.log(`[${label}] Already patched`)
      if (stopOnFirst) process.exit(0)
      continue
    }

    const matches = patch.search(content)

    if (matches.length === 0) {
      if (!stopOnFirst) console.log(`[${label}] Pattern not found, skipping`)
      continue
    }

    const extra = formatMatch ? `: ${formatMatch(patch, matches[0])}` : ""
    console.log(`[${label}] Patched${extra}`)

    content = patch.replace(content, matches)
    appliedPatches.push(patch)
    patchedCount++

    if (stopOnFirst) break
  }

  if (patchedCount === 0) {
    if (stopOnFirst) {
      console.error(`Pattern not found`)
      console.error("Checked versions:")
      for (const p of applicablePatches) {
        console.error(`  - ${p.version || "*"}`)
      }
      process.exit(1)
    }
    console.log("\nNothing to patch")
    process.exit(0)
  }

  writeFileSync(cliPath, content)

  const verifyContent = readFileSync(cliPath, "utf-8")
  const allVerified = appliedPatches.every((patch) => {
    if (!patch.verify) return true
    const ok = patch.verify(verifyContent)
    if (!ok) console.error(`[${patch.name}] Verification failed`)
    return ok
  })

  if (allVerified) {
    console.log(`\nPatched ${patchedCount} location(s) successfully`)
  } else {
    console.error("\nPatch verification failed")
    process.exit(1)
  }
}

export function createRegexSearcher(regex: RegExp): (text: string) => IMatchPosition[] {
  return (text: string) => {
    const results: IMatchPosition[] = []
    const re = new RegExp(regex.source, regex.flags.includes("g") ? regex.flags : regex.flags + "g")
    let match: RegExpExecArray | null
    while ((match = re.exec(text)) !== null) {
      results.push({
        start: match.index,
        end: match.index + match[0].length,
        match: match[0],
        groups: match.slice(1),
      })
    }
    return results
  }
}

export function createStringSearcher(search: string): (text: string) => IMatchPosition[] {
  return (text: string) => {
    const results: IMatchPosition[] = []
    let idx = 0
    while ((idx = text.indexOf(search, idx)) !== -1) {
      results.push({ start: idx, end: idx + search.length, match: search })
      idx += search.length
    }
    return results
  }
}

export function createSimpleReplacer(
  replacement: string,
): (text: string, matches: IMatchPosition[]) => string {
  return (text, matches) => replaceMatches(text, matches, () => replacement)
}

export function createFunctionReplacer(
  fn: (match: string, ...groups: string[]) => string,
): (text: string, matches: IMatchPosition[]) => string {
  return (text, matches) => replaceMatches(text, matches, (m) => fn(m.match, ...(m.groups || [])))
}

export function createIncludesVerifier(str: string): (text: string) => boolean {
  return (text) => text.includes(str)
}
