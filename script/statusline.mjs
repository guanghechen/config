#!/usr/bin/env node

import { execSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import path from 'node:path'

await main()

async function main() {
  try {
    // Read JSON input from stdin
    const input = readFileSync(0, 'utf-8')
    const data = JSON.parse(input)

    // Get all parts in parallel
    const [modelPart, costPart, cwdInfo] = await Promise.all([
      getModelPart(data),
      getCostPart(data),
      getCwdPart(data),
    ])

    // Get git part (needs to run after cwd is determined)
    const gitPart = await getGitPart(cwdInfo.fullPath)

    // Output status line
    const statusline = [cwdInfo.display, gitPart, modelPart, costPart].filter(Boolean).join(' ')
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
    const branch = execSync('git branch --show-current', {
      cwd: fullCwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim()

    if (!branch) return ''

    const [aheadBehind, statusInfo] = await Promise.all([
      getAheadBehind(fullCwd),
      getStatusCounts(fullCwd),
    ])

    // Build status indicators (fish-style)
    const indicators = []
    if (aheadBehind.ahead > 0) indicators.push(`\x1b[32m↑${aheadBehind.ahead}\x1b[0m`)
    if (aheadBehind.behind > 0) indicators.push(`\x1b[31m↓${aheadBehind.behind}\x1b[0m`)
    if (statusInfo.staged > 0) indicators.push(`\x1b[32m●${statusInfo.staged}\x1b[0m`)
    if (statusInfo.unstaged > 0) indicators.push(`\x1b[31m✚${statusInfo.unstaged}\x1b[0m`)
    if (statusInfo.untracked > 0) indicators.push(`\x1b[34m…${statusInfo.untracked}\x1b[0m`)

    const statusStr = indicators.length > 0 ? `\x1b[90m|\x1b[0m${indicators.join('')}` : ''
    return `\x1b[90m(\x1b[91m\uea68 ${branch}${statusStr}\x1b[90m)\x1b[0m`
  } catch {
    // Not a git repository or git command failed
  }
  return ''
}

function getAheadBehind(cwd) {
  try {
    const result = execSync('git rev-list --left-right --count @{upstream}...HEAD', {
      cwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim()
    const [behind, ahead] = result.split(/\s+/).map(Number)
    return { ahead: ahead || 0, behind: behind || 0 }
  } catch {
    // No upstream configured or not a git repo
    return { ahead: 0, behind: 0 }
  }
}

function getStatusCounts(cwd) {
  try {
    const status = execSync('git status --porcelain', {
      cwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    })
    let staged = 0, unstaged = 0, untracked = 0
    for (const line of status.split('\n')) {
      if (!line) continue
      const x = line[0], y = line[1]
      if (x === '?' && y === '?') untracked++
      else {
        if (x !== ' ' && x !== '?') staged++
        if (y !== ' ' && y !== '?') unstaged++
      }
    }
    return { staged, unstaged, untracked }
  } catch {
    return { staged: 0, unstaged: 0, untracked: 0 }
  }
}

async function getModelPart(data) {
  const model = data.model?.display_name || 'Unknown'
  return `\x1b[90m ${model}\x1b[0m`
}

async function getCostPart(data) {
  const costUsd = data.cost?.total_cost_usd || 0
  return `\x1b[90m$${costUsd.toFixed(4)}\x1b[0m`
}
