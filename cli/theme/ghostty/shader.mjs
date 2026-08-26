#!/usr/bin/env node

import { existsSync } from 'node:fs'
import path from 'node:path'

import { PLATFORM, XDG_CONFIG_HOME } from '#env'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'
import { exec } from '#util/command'

import {
  listGhosttyShaders,
  selectGhosttyShader,
} from './state.mjs'

/** @typedef {import("../types.d.ts").IReporter} IReporter */

const silentReporter = {
  debug() {},
  info() {},
  warn() {},
  error() {},
}

/** @param {IReporter} reporter @param {string} home */
async function reloadGhostty(reporter, home) {
  if (PLATFORM === 'win') return
  if (!existsSync(path.join(home, '.git'))) return

  try {
    await exec({ reporter, cmd: 'pkill', args: ['-USR2', '-x', 'ghostty'], silent: true })
  } catch {
    reporter.warn('Shader state was saved, but Ghostty could not be reloaded')
  }
}

/**
 * @typedef {Object} IGhosttyShaderOptions
 * @property {boolean} [silent]
 * @property {boolean} [prev]
 * @property {boolean} [next]
 * @property {boolean} [list]
 */

/**
 * @param {IReporter} reporter
 * @param {string} home
 * @param {IGhosttyShaderOptions} options
 * @param {string|undefined} shader
 */
export async function handleGhosttyShader(reporter, home, options, shader) {
  if (options.list) {
    if (shader || options.prev || options.next) {
      throw new Error('--list cannot be combined with a shader name, --prev, or --next')
    }
    const shaders = await listGhosttyShaders({ home })
    process.stdout.write(`${shaders.join('\n')}\n`)
    return
  }

  const selected = await selectGhosttyShader({
    home,
    shader,
    previous: options.prev,
    next: options.next,
  })

  if (selected.shader === 'off') {
    reporter.info(`Shader disabled (${selected.appearance})`)
  } else {
    reporter.info(`Shader (${selected.appearance}):`, selected.shader)
  }
  await reloadGhostty(reporter, home)
}

if (process.argv[1] === import.meta.filename) {
  const home = path.join(XDG_CONFIG_HOME, 'ghostty')
  const cmd = new Command({
    name: 'ghostty-shader',
    description: 'Manage the Ghostty shader selected for each appearance.',
  })
    .argument({ name: 'shader', kind: 'optional', description: 'Shader name' })
    .option({ long: 'silent', short: 's', type: 'boolean', description: 'Suppress output' })
    .option({ long: 'prev', type: 'boolean', description: 'Select the previous shader' })
    .option({ long: 'next', type: 'boolean', description: 'Select the next shader' })
    .option({ long: 'list', type: 'boolean', description: 'List shaders for the current appearance' })
    .action(async ({ args, opts }) => {
      const reporter = opts.silent
        ? silentReporter
        : new Reporter({ prefix: 'ghostty-shader' })
      await handleGhosttyShader(
        reporter,
        home,
        /** @type {IGhosttyShaderOptions} */ (opts),
        /** @type {string|undefined} */ (args.shader),
      )
    })

  await cmd.run({
    argv: process.argv.slice(2),
    envs: /** @type {Record<string, string>} */ (process.env),
  })
}
