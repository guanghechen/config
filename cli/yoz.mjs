#!/usr/bin/env node

/**
 * Preview file with yoz server.
 */

import fs from 'node:fs'
import https from 'node:https'
import path from 'node:path'
import { execSync } from 'node:child_process'
import { XDG_CONFIG_HOME, IS_NIX, IS_OSX, IS_WIN, IS_WSL } from '#env'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'yoz' })

/**
 * Try clipboard commands in order, return true on first success.
 * @param {string} text
 * @param {string[]} commands
 * @returns {boolean}
 */
function tryClipboardCommands(text, commands) {
  for (const cmd of commands) {
    try {
      execSync(cmd, { input: text, stdio: ['pipe', 'ignore', 'ignore'] })
      return true
    } catch {
      // Try next command
    }
  }
  return false
}

/**
 * Copy text to clipboard based on platform.
 * @param {string} text
 * @returns {boolean}
 */
function copyToClipboard(text) {
  if (IS_OSX) {
    return tryClipboardCommands(text, ['pbcopy'])
  }
  if (IS_WSL) {
    // WSL: try clip.exe first (Windows interop), fallback to Linux clipboard tools (WSLg)
    return tryClipboardCommands(text, ['clip.exe', 'xclip -selection clipboard', 'wl-copy'])
  }
  if (IS_WIN) {
    return tryClipboardCommands(text, ['powershell.exe -Command "Set-Clipboard -Value $input"'])
  }
  if (IS_NIX) {
    // Linux: try xclip (X11) first, then wl-copy (Wayland)
    return tryClipboardCommands(text, ['xclip -selection clipboard', 'wl-copy'])
  }
  return false
}

/**
 * Handle auth subcommand - copy YOZ_AUTH_TOKEN to clipboard.
 * @returns {Promise<void>}
 */
async function handleAuth() {
  const envFile = path.join(XDG_CONFIG_HOME, 'yoz', '.env.local')

  if (!fs.existsSync(envFile)) {
    reporter.error(`${envFile} not found`)
    process.exitCode = 1
    return
  }

  const content = fs.readFileSync(envFile, 'utf-8')
  const match = content.match(/^YOZ_AUTH_TOKEN=(.+)$/m)

  if (!match || !match[1]) {
    reporter.error(`YOZ_AUTH_TOKEN not found in ${envFile}`)
    process.exitCode = 1
    return
  }

  // Trim potential CRLF line endings from Windows
  const token = match[1].trim()

  if (!copyToClipboard(token)) {
    reporter.error('No clipboard tool found (tried pbcopy, clip.exe, powershell, xclip, wl-copy)')
    process.exitCode = 1
    return
  }

  reporter.info('YOZ_AUTH_TOKEN copied to clipboard')
}

/**
 * Handle file switch - send request to yoz server.
 * @param {string} filepath
 * @param {boolean} force
 * @returns {Promise<void>}
 */
async function handleFileSwitch(filepath, force) {
  const port = process.env.YOZ_SERVER_PORT

  if (!port) {
    reporter.error('YOZ_SERVER_PORT not set')
    process.exitCode = 1
    return
  }

  const absolutePath = path.resolve(filepath)
  const encodedPath = encodeURIComponent(absolutePath)
  const urlPath = `/api/file/switch?filepath=${encodedPath}&force=${force}`

  await new Promise(resolve => {
    const req = https.request(
      {
        hostname: 'localhost',
        port: Number(port),
        path: urlPath,
        method: 'POST',
        rejectUnauthorized: false,
      },
      res => {
        res.destroy()
        resolve(undefined)
      },
    )
    req.on('error', () => {
      // Ignore errors - fire and forget like the original fish function
      resolve(undefined)
    })
    req.end()
  })
}

/**
 * @typedef {Object} IYozOptions
 * @property {boolean} [force]
 */

/**
 * @param {IYozOptions} opts
 * @param {string} [filepath]
 * @returns {Promise<void>}
 */
export async function handleYoz(opts, filepath) {
  if (!filepath) {
    reporter.error('Usage: yoz <filepath> [--force]')
    process.exitCode = 1
    return
  }

  await handleFileSwitch(filepath, opts.force ?? false)
}

if (process.argv[1] === import.meta.filename) {
  const authCmd = new Command({ name: 'auth', description: 'Copy YOZ_AUTH_TOKEN to clipboard.' })
    .action(async () => {
      await handleAuth()
    })

  const cmd = new Command({ name: 'yoz', description: 'Preview file with yoz server.', help: true })
    .argument({ name: 'filepath', kind: 'optional', description: 'File path to preview' })
    .option({ long: 'force', type: 'boolean', description: 'Force refresh' })
    .subcommand('auth', authCmd)
    .action(async ({ args, opts }) => {
      await handleYoz(
        /** @type {IYozOptions} */ (opts),
        /** @type {string | undefined} */ (args.filepath),
      )
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
