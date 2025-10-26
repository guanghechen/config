#!/usr/bin/env node

import { execSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { homedir } from 'node:os'
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
  const home = homedir()
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
    display: `\x1b[0m󱃪 ${cwd}\x1b[0m`,
    fullPath: fullCwd,
  }
}

async function getGitPart(fullCwd) {
  try {
    process.chdir(fullCwd)
    const branch = execSync('git branch --show-current 2>/dev/null', {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    }).trim()

    if (branch) {
      return `\x1b[0m(\x1b[91m ${branch}\x1b[0m)`
    }
  } catch (err) {
    // Not a git repository or git command failed
  }
  return ''
}

async function getModelPart(data) {
  const model = data.model?.display_name || 'Unknown'
  return `\x1b[36m\x1b[0m ${model}\x1b[0m`
}

async function getCostPart(data) {
  const costUsd = data.cost?.total_cost_usd || 0
  return `\x1b[0m$${costUsd.toFixed(4)}\x1b[0m`
}
