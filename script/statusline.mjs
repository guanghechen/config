#!/usr/bin/env node

import { execSync } from 'node:child_process'
import { readFileSync, existsSync } from 'node:fs'
import path from 'node:path'

await main()

async function main() {
  try {
    // Read JSON input from stdin
    const input = readFileSync(0, 'utf-8')
    const data = JSON.parse(input)

    // Get all parts in parallel
    const [modelPart, costPart, cwdInfo, contextPart, stylePart] = await Promise.all([
      getModelPart(data),
      getCostPart(data),
      getCwdPart(data),
      getContextPart(data),
      getStylePart(data),
    ])

    // Get git part (needs to run after cwd is determined)
    const gitPart = await getGitPart(cwdInfo.fullPath)

    // Output status line with │ separator
    // Order: cwd, git, model, context, cost, style
    const sep = '\x1b[90m│\x1b[0m'
    const statusline = [cwdInfo.display, gitPart, modelPart, contextPart, costPart, stylePart].filter(Boolean).join(` ${sep} `)
    process.stdout.write(statusline)
  } catch (err) {
    // Fallback output if something goes wrong
    process.stdout.write('[Claude Code]')
  }
}

async function getCwdPart(data) {
  const fullCwd = path.normalize(data.cwd || process.cwd())
  let cwd = fullCwd

  // Replace home directory with ~
  const home = process.env.HOME || process.env.USERPROFILE
  if (cwd.startsWith(home)) {
    cwd = '~' + cwd.slice(home.length)
  }

  // Abbreviate parent directories to first letter only
  const parts = cwd.split(path.sep)
  if (parts.length > 1) {
    const abbreviated = parts.slice(0, -1).map(part => {
      if (part === '~' || part === '') return part
      // Show first two letters for dotfiles/dotfolders
      if (part[0] === '.') return part.slice(0, 2)
      return part[0]
    })
    cwd = [...abbreviated, parts[parts.length - 1]].join(path.sep)
  }

  return {
    display: `\x1b[94m󱃪 ${cwd}\x1b[0m`,
    fullPath: fullCwd,
  }
}

async function getGitPart(fullCwd) {
  try {
    // Use single git status -sb command to get branch, ahead/behind, and file status
    const status = execSync('git status -sb', {
      cwd: fullCwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    })

    const lines = status.split('\n')
    const headerLine = lines[0] || ''

    // Parse header: "## branch...origin/branch [ahead 1, behind 2]" or "## HEAD (no branch)"
    let branch = ''
    let ahead = 0, behind = 0

    const headerMatch = headerLine.match(/^## (.+?)(?:\.\.\.(\S+))?(?:\s+\[(.+)\])?$/)
    if (headerMatch) {
      branch = headerMatch[1]
      const trackingInfo = headerMatch[3]
      if (trackingInfo) {
        const aheadMatch = trackingInfo.match(/ahead (\d+)/)
        const behindMatch = trackingInfo.match(/behind (\d+)/)
        if (aheadMatch) ahead = parseInt(aheadMatch[1], 10)
        if (behindMatch) behind = parseInt(behindMatch[1], 10)
      }
    }

    // Handle detached HEAD - show short commit hash
    if (branch === 'HEAD (no branch)' || branch === 'HEAD') {
      try {
        const shortHash = execSync('git rev-parse --short HEAD', {
          cwd: fullCwd,
          encoding: 'utf-8',
          stdio: ['pipe', 'pipe', 'pipe'],
        }).trim()
        branch = `@${shortHash}`
      } catch {
        branch = '@detached'
      }
    }

    if (!branch) return ''

    // Check for conflict state (merge, rebase, cherry-pick, etc.)
    const conflictState = getConflictState(fullCwd)

    // Count file statuses from remaining lines
    let staged = 0, unstaged = 0, untracked = 0, conflicts = 0
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]
      if (!line) continue
      const x = line[0], y = line[1]
      // Conflict markers: UU, AA, DD, AU, UA, DU, UD
      if ((x === 'U' || y === 'U') || (x === 'A' && y === 'A') || (x === 'D' && y === 'D')) {
        conflicts++
      } else if (x === '?' && y === '?') {
        untracked++
      } else {
        if (x !== ' ' && x !== '?') staged++
        if (y !== ' ' && y !== '?') unstaged++
      }
    }

    // Build status indicators (fish-style)
    const indicators = []
    if (conflictState) indicators.push(`\x1b[31;1m${conflictState}\x1b[0m`)
    if (conflicts > 0) indicators.push(`\x1b[31;1m✖${conflicts}\x1b[0m`)
    if (ahead > 0) indicators.push(`\x1b[32m↑${ahead}\x1b[0m`)
    if (behind > 0) indicators.push(`\x1b[31m↓${behind}\x1b[0m`)
    if (staged > 0) indicators.push(`\x1b[32m•${staged}\x1b[0m`)
    if (unstaged > 0) indicators.push(`\x1b[31m+${unstaged}\x1b[0m`)
    if (untracked > 0) indicators.push(`\x1b[34m?${untracked}\x1b[0m`)

    const statusStr = indicators.length > 0 ? `\x1b[90m|\x1b[0m${indicators.join('')}` : ''
    return `\x1b[95m\uea68 ${branch}${statusStr}\x1b[0m`
  } catch {
    // Not a git repository or git command failed
  }
  return ''
}

function getConflictState(cwd) {
  try {
    // Check for various in-progress operations by testing file existence
    const gitDir = execSync('git rev-parse --git-dir', {
      cwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim()

    const fullGitDir = path.isAbsolute(gitDir) ? gitDir : path.join(cwd, gitDir)

    if (existsSync(path.join(fullGitDir, 'MERGE_HEAD'))) return '⚡merge'
    if (existsSync(path.join(fullGitDir, 'rebase-merge')) || existsSync(path.join(fullGitDir, 'rebase-apply'))) return '⚡rebase'
    if (existsSync(path.join(fullGitDir, 'CHERRY_PICK_HEAD'))) return '⚡pick'
    if (existsSync(path.join(fullGitDir, 'REVERT_HEAD'))) return '⚡revert'
    if (existsSync(path.join(fullGitDir, 'BISECT_LOG'))) return '⚡bisect'
  } catch {
    // Ignore errors
  }
  return ''
}

function getModelPart(data) {
  const model = data.model?.display_name || 'Unknown'
  return `\x1b[96m󰘦 ${model}\x1b[0m`
}

function getCostPart(data) {
  const costUsd = data.cost?.total_cost_usd || 0
  return `\x1b[93m$${costUsd.toFixed(4)}\x1b[0m`
}

function getContextPart(data) {
  const ctx = data.context_window
  if (!ctx) return ''

  const windowSize = ctx.context_window_size || 0
  if (windowSize === 0) return ''

  const usage = ctx.current_usage
  let currentTokens = 0
  if (usage) {
    currentTokens = (usage.input_tokens || 0) +
      (usage.cache_creation_input_tokens || 0) +
      (usage.cache_read_input_tokens || 0)
  }

  const percent = Math.round((currentTokens / windowSize) * 100)
  const usedK = (currentTokens / 1000).toFixed(1)
  const totalK = (windowSize / 1000).toFixed(0)

  // Color based on usage: green < 50%, yellow 50-80%, red > 80%
  let color = '\x1b[32m' // green
  if (percent >= 80) color = '\x1b[31m' // red
  else if (percent >= 50) color = '\x1b[33m' // yellow

  return `${color}󰍛 ${usedK}k/${totalK}k (${percent}%)\x1b[0m`
}

function getStylePart(data) {
  const style = data.output_style?.name || 'default'
  return `\x1b[90m󰉼 ${style}\x1b[0m`
}
