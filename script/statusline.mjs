#!/usr/bin/env node

import { execSync } from 'node:child_process'
import { readFileSync, existsSync } from 'node:fs'
import path from 'node:path'

class StatuslineComponent {
  constructor(data) {
    this.data = data
    this.cwd = path.normalize(data.cwd || process.cwd())
  }

  async render() {
    const parts = await Promise.all([
      this.path(),
      this.git(),
      this.model(),
      this.context(),
      this.cost(),
      this.style(),
    ])
    const sep = '\x1b[90m│\x1b[0m'
    return parts.filter(Boolean).join(` ${sep} `)
  }

  path() {
    let display = this.cwd
    const home = process.env.HOME || process.env.USERPROFILE
    if (display.startsWith(home)) {
      display = '~' + display.slice(home.length)
    }
    const parts = display.split(path.sep)
    if (parts.length > 1) {
      const abbreviated = parts.slice(0, -1).map(p => {
        if (p === '~' || p === '') return p
        if (p[0] === '.') return p.slice(0, 2)
        return p[0]
      })
      display = [...abbreviated, parts.at(-1)].join(path.sep)
    }
    return `\x1b[94m󱃪 ${display}\x1b[0m`
  }

  git() {
    try {
      const status = execSync('git status -sb', {
        cwd: this.cwd,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      })
      const lines = status.split('\n')
      const header = lines[0] || ''

      let branch = '', ahead = 0, behind = 0
      const m = header.match(/^## (.+?)(?:\.\.\.(\S+))?(?:\s+\[(.+)\])?$/)
      if (m) {
        branch = m[1]
        if (m[3]) {
          ahead = parseInt(m[3].match(/ahead (\d+)/)?.[1] || 0, 10)
          behind = parseInt(m[3].match(/behind (\d+)/)?.[1] || 0, 10)
        }
      }

      if (branch === 'HEAD (no branch)' || branch === 'HEAD') {
        try {
          const hash = execSync('git rev-parse --short HEAD', {
            cwd: this.cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'],
          }).trim()
          branch = `@${hash}`
        } catch { branch = '@detached' }
      }

      if (!branch) return ''

      const conflict = this.#conflictState()
      const stash = this.#stashCount()
      const files = this.#parseFiles(lines.slice(1))
      const ind = this.#buildIndicators({ conflict, ahead, behind, stash, ...files })

      return `\x1b[95m\uea68 ${branch}${ind}\x1b[0m`
    } catch { return '' }
  }

  #conflictState() {
    try {
      const gitDir = execSync('git rev-parse --git-dir', {
        cwd: this.cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'],
      }).trim()
      const dir = path.isAbsolute(gitDir) ? gitDir : path.join(this.cwd, gitDir)

      if (existsSync(path.join(dir, 'MERGE_HEAD'))) return '⚡merge'
      if (existsSync(path.join(dir, 'rebase-merge')) || existsSync(path.join(dir, 'rebase-apply'))) return '⚡rebase'
      if (existsSync(path.join(dir, 'CHERRY_PICK_HEAD'))) return '⚡pick'
      if (existsSync(path.join(dir, 'REVERT_HEAD'))) return '⚡revert'
      if (existsSync(path.join(dir, 'BISECT_LOG'))) return '⚡bisect'
    } catch {}
    return ''
  }

  #stashCount() {
    try {
      const list = execSync('git stash list', {
        cwd: this.cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'],
      })
      return list.split('\n').filter(Boolean).length
    } catch { return 0 }
  }

  #parseFiles(lines) {
    const r = {
      conflicts: 0, untracked: 0,
      stagedM: 0, stagedA: 0, stagedD: 0, stagedR: 0,
      unstagedM: 0, unstagedA: 0, unstagedD: 0, unstagedR: 0,
    }
    for (const line of lines) {
      if (!line) continue
      const [x, y] = line
      if ((x === 'U' || y === 'U') || (x === 'A' && y === 'A') || (x === 'D' && y === 'D')) {
        r.conflicts++
      } else if (x === '?' && y === '?') {
        r.untracked++
      } else {
        if (x === 'M') r.stagedM++
        else if (x === 'A') r.stagedA++
        else if (x === 'D') r.stagedD++
        else if (x === 'R') r.stagedR++
        if (y === 'M') r.unstagedM++
        else if (y === 'A') r.unstagedA++
        else if (y === 'D') r.unstagedD++
        else if (y === 'R') r.unstagedR++
      }
    }
    return r
  }

  #buildIndicators({ conflict, conflicts, ahead, behind, stash, stagedM, stagedA, stagedD, stagedR, unstagedM, unstagedA, unstagedD, unstagedR, untracked }) {
    const ind = []
    if (conflict) ind.push(`\x1b[91;1m${conflict}\x1b[0m`)
    if (conflicts > 0) ind.push(`\x1b[91;1m✖${conflicts}\x1b[0m`)
    if (ahead > 0) ind.push(`\x1b[94m↑${ahead}\x1b[0m`)
    if (behind > 0) ind.push(`\x1b[95m↓${behind}\x1b[0m`)
    if (stash > 0) ind.push(`\x1b[94m⚑${stash}\x1b[0m`)
    if (stagedM > 0) ind.push(`\x1b[92m●${stagedM}\x1b[0m`)
    if (stagedA > 0) ind.push(`\x1b[92m+${stagedA}\x1b[0m`)
    if (stagedD > 0) ind.push(`\x1b[92m−${stagedD}\x1b[0m`)
    if (stagedR > 0) ind.push(`\x1b[92m→${stagedR}\x1b[0m`)
    if (unstagedM > 0) ind.push(`\x1b[93m●${unstagedM}\x1b[0m`)
    if (unstagedA > 0) ind.push(`\x1b[93m+${unstagedA}\x1b[0m`)
    if (unstagedD > 0) ind.push(`\x1b[93m−${unstagedD}\x1b[0m`)
    if (unstagedR > 0) ind.push(`\x1b[93m→${unstagedR}\x1b[0m`)
    if (untracked > 0) ind.push(`\x1b[90m?${untracked}\x1b[0m`)
    return ind.length ? ` ${ind.join('')}` : ''
  }

  model() {
    const name = this.data.model?.display_name || 'Unknown'
    return `\x1b[96m󰘦 ${name}\x1b[0m`
  }

  cost() {
    const usd = this.data.cost?.total_cost_usd || 0
    return `\x1b[93m$${usd.toFixed(4)}\x1b[0m`
  }

  context() {
    const ctx = this.data.context_window
    if (!ctx?.context_window_size) return ''

    const total = ctx.context_window_size
    const usage = ctx.current_usage
    const used = usage
      ? (usage.input_tokens || 0) + (usage.cache_creation_input_tokens || 0) + (usage.cache_read_input_tokens || 0)
      : 0

    const pct = Math.round((used / total) * 100)
    const color = pct >= 80 ? '\x1b[91m' : pct >= 50 ? '\x1b[93m' : '\x1b[92m'
    return `${color}󰍛 ${(used / 1000).toFixed(1)}k/${(total / 1000).toFixed(0)}k (${pct}%)\x1b[0m`
  }

  style() {
    const name = this.data.output_style?.name || 'default'
    return `\x1b[90m󰉼 ${name}\x1b[0m`
  }
}

try {
  const input = readFileSync(0, 'utf-8')
  const data = JSON.parse(input)
  const component = new StatuslineComponent(data)
  process.stdout.write(await component.render())
} catch {
  process.stdout.write('[Claude Code]')
}
