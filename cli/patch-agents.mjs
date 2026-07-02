#!/usr/bin/env node

/**
 * Patch AI coding agents (Claude Code, etc.) to customize behavior.
 */

import { spawn } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const __dirname = dirname(fileURLToPath(import.meta.url))
const reporter = new Reporter({ prefix: 'patch-agents' })

/**
 * @typedef {Object} IPatchAgentsOptions
 * @property {string} [agent]
 */

/**
 * Run a patch script.
 * @param {string} name
 * @param {string} script
 * @param {string[]} args
 * @returns {Promise<number>}
 */
function runPatch(name, script, args) {
  console.log(`\n${'='.repeat(50)}`)
  console.log(`Running: ${name}`)
  console.log('='.repeat(50))

  return new Promise((resolve) => {
    spawn(process.execPath, [script, ...args], { stdio: 'inherit' }).on('close', (code) => resolve(code ?? 0))
  })
}

/**
 * @param {IPatchAgentsOptions} opts
 * @returns {Promise<void>}
 */
export async function handlePatchAgents(opts) {
  const agent = opts.agent ?? 'claude'

  const agentDir = join(__dirname, 'patch', agent)

  const patches = [
    { name: 'image-paste', file: 'patch-image-paste.mjs', args: [] },
  ]

  let hasError = false

  for (const { name, file, args } of patches) {
    const script = join(agentDir, file)
    const code = await runPatch(name, script, args)
    if (code !== 0) hasError = true
  }

  if (hasError) {
    process.exitCode = 1
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'patch-agents', description: 'Patch AI coding agents to customize behavior.' })
    .option({ long: 'agent', type: 'string', default: 'claude', description: 'Agent to patch (claude)' })
    .action(async ({ opts }) => {
      await handlePatchAgents(/** @type {IPatchAgentsOptions} */ (opts))
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
