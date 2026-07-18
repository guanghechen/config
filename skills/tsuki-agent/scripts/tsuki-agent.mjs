#!/usr/bin/env node

import { spawn } from 'node:child_process'
import { access } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const repositoryCliPath = fileURLToPath(
  new URL('../../../packages/agent-bridge/cli/tsuki-agent.mjs', import.meta.url),
)
const configuredCliPath = process.env.TSUKI_AGENT_CLI_PATH
const repositoryCliAvailable = await isReadable(repositoryCliPath)
const command = configuredCliPath || (repositoryCliAvailable ? process.execPath : 'tsuki-agent')
const commandArgs =
  configuredCliPath || repositoryCliAvailable
    ? [configuredCliPath || repositoryCliPath, ...process.argv.slice(2)]
    : process.argv.slice(2)
const child = spawn(command, commandArgs, {
  stdio: 'inherit',
})

child.on('error', error => {
  process.stderr.write(
    `Could not start the Tsuki agent companion: ${error.message}\n` +
      'Install tsuki-agent on PATH or set TSUKI_AGENT_CLI_PATH.\n',
  )
  process.exitCode = 1
})

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal)
    return
  }
  process.exitCode = code ?? 1
})

async function isReadable(path) {
  try {
    await access(path)
    return true
  } catch {
    return false
  }
}
