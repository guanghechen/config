#!/usr/bin/env node

/**
 * Clone or pull an opensource repository.
 */

import fs from 'node:fs'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

/** @typedef {'github'} IPlatform */

/**
 * @typedef {Object} IOpensourceOptions
 * @property {IPlatform} [platform]
 */

/**
 * @typedef {Object} IOpensourceResult
 * @property {boolean} success
 * @property {string} [targetDir]
 */

const reporter = new Reporter({ prefix: 'opensource' })

/**
 * Run a git command and stream output to console.
 * @param {string[]} args
 * @param {string} [cwd]
 * @returns {boolean}
 */
function runGit(args, cwd) {
  const result = spawnSync('git', args, { cwd, stdio: 'inherit' })
  return result.status === 0
}

/**
 * Handle opensource clone/pull for GitHub.
 * @param {string} repoPath - Format: author/reponame
 * @param {Record<string, string | undefined>} envs
 * @returns {IOpensourceResult}
 */
function handleGitHub(repoPath, envs) {
  const rootSourcecodes = envs.ROOT_SOURCECODES

  if (!rootSourcecodes) {
    reporter.error('ROOT_SOURCECODES is not set')
    return { success: false }
  }

  const parts = repoPath.split('/')
  if (parts.length !== 2) {
    reporter.error('Invalid format. Expected <author/reponame>')
    return { success: false }
  }

  const [author, reponame] = parts
  const targetDir = path.join(rootSourcecodes, 'github', author, reponame)

  // If repo already exists, pull
  if (fs.existsSync(path.join(targetDir, '.git'))) {
    reporter.info(`Pulling ${repoPath}...`)
    const success = runGit(['pull', 'origin'], targetDir)
    return { success, targetDir }
  }

  // Clone new repo
  const parentDir = path.join(rootSourcecodes, 'github', author)
  fs.mkdirSync(parentDir, { recursive: true })

  reporter.info(`Cloning ${repoPath}...`)
  const success = runGit(['clone', `https://github.com/${author}/${reponame}.git`], parentDir)
  return { success, targetDir }
}

/**
 * @param {IOpensourceOptions} opts
 * @param {string | undefined} repoPath
 * @param {Record<string, string | undefined>} envs
 * @returns {Promise<void>}
 */
export async function handleOpensource(opts, repoPath, envs) {
  if (!repoPath) {
    reporter.error('Usage: opensource [--platform github] <author/reponame>')
    process.exitCode = 1
    return
  }

  const platform = opts.platform ?? 'github'

  /** @type {IOpensourceResult} */
  let result

  switch (platform) {
    case 'github':
      result = handleGitHub(repoPath, envs)
      break
    default:
      reporter.error(`Unknown platform: ${platform}`)
      process.exitCode = 1
      return
  }

  if (!result.success) {
    process.exitCode = 1
    return
  }

  if (result.targetDir) {
    // Output the target directory for the fish wrapper to cd into
    process.stdout.write(`CD:${result.targetDir}\n`)
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'opensource', description: 'Clone or pull an opensource repository.', help: true })
    .argument({ name: 'repoPath', kind: 'required', description: 'Repository path in format <author/reponame>' })
    .option({ long: 'platform', type: 'string', default: 'github', description: 'Platform to use (github)' })
    .action(async ({ args, opts }) => {
      await handleOpensource(
        /** @type {IOpensourceOptions} */ (opts),
        /** @type {string | undefined} */ (args.repoPath),
        /** @type {Record<string, string>} */ (process.env),
      )
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
