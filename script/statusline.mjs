#!/usr/bin/env node

import { execSync } from "node:child_process"
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"

const GIT_CACHE_TTL_MS = 5000

const ANSI = {
  reset: "\x1b[0m",
  gray: "\x1b[90m",
  red: "\x1b[91m",
  redBold: "\x1b[91;1m",
  green: "\x1b[92m",
  yellow: "\x1b[93m",
  blue: "\x1b[94m",
  magenta: "\x1b[95m",
  cyan: "\x1b[96m",
}

// GIT_OPTIONAL_LOCKS=0 prevents `git status` from refreshing the index
// (which would take .git/index.lock and race the user's own git commands).
const GIT_ENV = { ...process.env, GIT_OPTIONAL_LOCKS: "0" }

function execGit(cwd, cmd) {
  return execSync(cmd, { cwd, encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"], env: GIT_ENV }).trim()
}

function abbreviatePath(cwd) {
  const home = process.env.HOME || process.env.USERPROFILE
  let display = cwd
  if (home && display.startsWith(home)) {
    display = "~" + display.slice(home.length)
  }
  const parts = display.split(path.sep)
  if (parts.length <= 1) return display

  const abbreviated = parts.slice(0, -1).map((p) => {
    if (p === "~" || p === "") return p
    return p[0] === "." ? p.slice(0, 2) : p[0]
  })
  return [...abbreviated, parts.at(-1)].join(path.sep)
}

function parseGitFiles(lines) {
  const stats = {
    conflicts: 0,
    untracked: 0,
    stagedM: 0,
    stagedA: 0,
    stagedD: 0,
    stagedR: 0,
    unstagedM: 0,
    unstagedA: 0,
    unstagedD: 0,
    unstagedR: 0,
  }
  for (const line of lines) {
    if (!line) continue
    const [x, y] = line
    if (x === "U" || y === "U" || (x === "A" && y === "A") || (x === "D" && y === "D")) {
      stats.conflicts++
    } else if (x === "?" && y === "?") {
      stats.untracked++
    } else {
      if (x === "M") stats.stagedM++
      else if (x === "A") stats.stagedA++
      else if (x === "D") stats.stagedD++
      else if (x === "R") stats.stagedR++
      if (y === "M") stats.unstagedM++
      else if (y === "A") stats.unstagedA++
      else if (y === "D") stats.unstagedD++
      else if (y === "R") stats.unstagedR++
    }
  }
  return stats
}

function buildIndicators(conflict, ahead, behind, stash, stats) {
  const ind = []
  const { redBold, blue, magenta, green, yellow, gray, reset } = ANSI

  if (conflict) ind.push(`${redBold}${conflict}${reset}`)
  if (stats.conflicts > 0) ind.push(`${redBold}✖${stats.conflicts}${reset}`)
  if (ahead > 0) ind.push(`${blue}↑${ahead}${reset}`)
  if (behind > 0) ind.push(`${magenta}↓${behind}${reset}`)
  if (stash > 0) ind.push(`${blue}⚑${stash}${reset}`)
  if (stats.stagedM > 0) ind.push(`${green}●${stats.stagedM}${reset}`)
  if (stats.stagedA > 0) ind.push(`${green}+${stats.stagedA}${reset}`)
  if (stats.stagedD > 0) ind.push(`${green}−${stats.stagedD}${reset}`)
  if (stats.stagedR > 0) ind.push(`${green}→${stats.stagedR}${reset}`)
  if (stats.unstagedM > 0) ind.push(`${yellow}●${stats.unstagedM}${reset}`)
  if (stats.unstagedA > 0) ind.push(`${yellow}+${stats.unstagedA}${reset}`)
  if (stats.unstagedD > 0) ind.push(`${yellow}−${stats.unstagedD}${reset}`)
  if (stats.unstagedR > 0) ind.push(`${yellow}→${stats.unstagedR}${reset}`)
  if (stats.untracked > 0) ind.push(`${gray}?${stats.untracked}${reset}`)

  return ind.length ? ` ${ind.join("")}` : ""
}

function getConflictState(cwd) {
  try {
    const gitDir = execGit(cwd, "git rev-parse --git-dir")
    const dir = path.isAbsolute(gitDir) ? gitDir : path.join(cwd, gitDir)

    if (existsSync(path.join(dir, "MERGE_HEAD"))) return "⚡merge"
    if (existsSync(path.join(dir, "rebase-merge")) || existsSync(path.join(dir, "rebase-apply")))
      return "⚡rebase"
    if (existsSync(path.join(dir, "CHERRY_PICK_HEAD"))) return "⚡pick"
    if (existsSync(path.join(dir, "REVERT_HEAD"))) return "⚡revert"
    if (existsSync(path.join(dir, "BISECT_LOG"))) return "⚡bisect"
  } catch {
    // ignore
  }
  return ""
}

function getStashCount(cwd) {
  try {
    return execGit(cwd, "git stash list").split("\n").filter(Boolean).length
  } catch {
    return 0
  }
}

function renderPath(cwd) {
  return `${ANSI.blue}󱃪 ${abbreviatePath(cwd)}${ANSI.reset}`
}

function getGitCachePath(data, cwd) {
  const session = data.session_id || "no-session"
  const key = createHash("sha1").update(`${session}\0${cwd}`).digest("hex")
  return path.join(os.tmpdir(), "claude-statusline", `${key}.json`)
}

function readGitCache(file) {
  try {
    if (Date.now() - statSync(file).mtimeMs > GIT_CACHE_TTL_MS) return null

    const cached = JSON.parse(readFileSync(file, "utf-8"))
    return typeof cached.output === "string" ? cached.output : null
  } catch {
    return null
  }
}

function writeGitCache(file, output) {
  try {
    mkdirSync(path.dirname(file), { recursive: true })
    writeFileSync(file, JSON.stringify({ output }), "utf-8")
  } catch {
    // ignore
  }
}

function renderGitUncached(cwd) {
  try {
    const status = execGit(cwd, "git status -sb")
    const lines = status.split("\n")
    const header = lines[0] || ""

    let branch = ""
    let ahead = 0
    let behind = 0
    const m = header.match(/^## (.+?)(?:\.\.\.(\S+))?(?:\s+\[(.+)\])?$/)
    if (m) {
      branch = m[1]
      if (m[3]) {
        ahead = parseInt(m[3].match(/ahead (\d+)/)?.[1] || "0", 10)
        behind = parseInt(m[3].match(/behind (\d+)/)?.[1] || "0", 10)
      }
    }

    if (branch === "HEAD (no branch)" || branch === "HEAD") {
      try {
        branch = `@${execGit(cwd, "git rev-parse --short HEAD")}`
      } catch {
        branch = "@detached"
      }
    }

    if (!branch) return ""

    const conflict = getConflictState(cwd)
    const stash = getStashCount(cwd)
    const stats = parseGitFiles(lines.slice(1))
    const ind = buildIndicators(conflict, ahead, behind, stash, stats)

    return `${ANSI.magenta}\uea68 ${branch}${ind}${ANSI.reset}`
  } catch {
    return ""
  }
}

function renderGit(data, cwd) {
  const cacheFile = getGitCachePath(data, cwd)
  const cached = readGitCache(cacheFile)
  if (cached !== null) return cached

  const output = renderGitUncached(cwd)
  writeGitCache(cacheFile, output)
  return output
}

function renderModel(data) {
  return `${ANSI.cyan}󰘦 ${data.model?.display_name || "Unknown"}${ANSI.reset}`
}

function renderCost(data) {
  const usd = data.cost?.total_cost_usd || 0
  return `${ANSI.yellow}$${usd.toFixed(4)}${ANSI.reset}`
}

function renderContext(data) {
  const ctx = data.context_window
  if (!ctx?.context_window_size) return ""

  const total = ctx.context_window_size
  const usage = ctx.current_usage
  const used = usage
    ? (usage.input_tokens || 0) +
      (usage.cache_creation_input_tokens || 0) +
      (usage.cache_read_input_tokens || 0)
    : 0

  const pct = Math.round((used / total) * 100)
  let color = ANSI.green
  if (pct >= 80) color = ANSI.red
  else if (pct >= 50) color = ANSI.yellow

  return `${color}󰍛 ${(used / 1000).toFixed(1)}k/${(total / 1000).toFixed(0)}k (${pct}%)${ANSI.reset}`
}

function renderStyle(data) {
  return `${ANSI.gray}󰉼 ${data.output_style?.name || "default"}${ANSI.reset}`
}

function formatDuration(ms) {
  const sec = Math.floor(ms / 1000)
  const d = Math.floor(sec / 86400)
  const h = Math.floor((sec % 86400) / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60

  if (d > 0) return `${d}d ${h}h ${m}m`
  if (h > 0) return `${h}h ${m}m`
  if (m > 0) return `${m}m ${s}s`
  return `${s}s`
}

function renderDuration(data) {
  const ms = data.cost?.total_duration_ms
  if (!ms) return ""
  return `${ANSI.gray}󱎫 ${formatDuration(ms)}${ANSI.reset}`
}

function renderTime() {
  const now = new Date()
  const pad = (n) => n.toString().padStart(2, "0")
  const hh = pad(now.getHours())
  const mi = pad(now.getMinutes())
  const ss = pad(now.getSeconds())
  return `${ANSI.gray}󰥔 ${hh}:${mi}:${ss}${ANSI.reset}`
}

function render(data) {
  const cwd = path.normalize(data.cwd || process.cwd())
  const parts = [
    renderPath(cwd),
    renderGit(data, cwd),
    renderModel(data),
    renderContext(data),
    renderCost(data),
    renderStyle(data),
    renderDuration(data),
    renderTime(),
  ].filter(Boolean)

  const sep = `${ANSI.gray}│${ANSI.reset}`
  return parts.join(` ${sep} `)
}

try {
  const input = readFileSync(0, "utf-8")
  const data = JSON.parse(input)
  process.stdout.write(render(data))
} catch {
  process.stdout.write("[Claude Code]")
}
