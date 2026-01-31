import path from 'node:path'
import { exec } from '#util/command'
import { is_directory } from '#util/path'

/**
 * @typedef {Object} IGitWorktreeConfig
 * @property {string} root - Root directory for worktrees
 * @property {string} main - Main repository path
 * @property {string} url - Git repository URL
 * @property {string} name - Repository name for logging
 * @property {string} branch - Main branch name
 * @property {string[]} requiredBranches - Branches that must exist
 * @property {string[]} optionalBranches - Branches that are optional
 */

/**
 * @typedef {import('@guanghechen/stl/reporter').Reporter} Reporter
 */

/**
 * Parse branch pattern: <branch_name> or <branch_name>:<target_dir>
 * @param {string} branch
 * @returns {{ name: string, target: string | null }}
 */
export function parse_branch(branch) {
  const parts = branch.split(':')
  return {
    name: parts[0],
    target: parts[1] ?? null,
  }
}

/**
 * Resolve repository path from target.
 * @param {string} root
 * @param {string} target
 * @returns {string}
 */
export function resolve_repo_path(root, target) {
  if (target.startsWith('/')) return target
  if (target.startsWith('~')) return target.replace(/^~/, process.env.HOME ?? '')
  return path.join(root, target)
}

/**
 * Sync main branch of a git repository.
 * @param {Reporter} reporter
 * @param {IGitWorktreeConfig} config
 */
export async function sync_main_branch(reporter, config) {
  const { root, main, url, name, branch } = config

  if (!is_directory(root)) {
    reporter.info(`[${name}] mkdir -p ${root}`)
    await exec({ reporter, cmd: 'mkdir', args: ['-p', root], silent: true })
  }

  if (is_directory(path.join(main, '.git'))) {
    reporter.info(`[${name}] fetching and merging origin/${branch}`)
    await exec({ reporter, cmd: 'git', args: ['-C', main, 'fetch', 'origin'], silent: true })
    await exec({
      reporter,
      cmd: 'git',
      args: ['-C', main, 'merge', `origin/${branch}`, '--ff-only'],
      silent: true,
    })
  } else {
    reporter.info(`[${name}] cloning ${url} (branch: ${branch})`)
    await exec({
      reporter,
      cmd: 'git',
      args: ['clone', url, `--branch=${branch}`, main],
      silent: true,
    })
  }
}

/**
 * Sync git worktrees for branches.
 * @param {Reporter} reporter
 * @param {IGitWorktreeConfig} config
 * @param {string[]} branches
 * @param {boolean} required
 */
export async function sync_worktrees(reporter, config, branches, required) {
  const { root, main, name } = config

  for (const branch of branches) {
    const { name: branchName, target } = parse_branch(branch)
    const repoPath = target ? resolve_repo_path(root, target) : path.join(root, branchName)

    if (is_directory(repoPath)) {
      reporter.info(`[${name}] syncing ${branchName}`)
      try {
        await exec({
          reporter,
          cmd: 'git',
          args: ['-C', repoPath, 'merge', `origin/${branchName}`, '--ff-only'],
          silent: true,
        })
      } catch {
        reporter.error(`[${name}] failed to sync ${branchName}`)
      }
    } else if (required) {
      reporter.info(`[${name}] add new worktree of ${branchName}`)
      try {
        await exec({
          reporter,
          cmd: 'git',
          args: ['-C', main, 'worktree', 'add', repoPath, branchName],
          silent: true,
        })
      } catch {
        reporter.error(`[${name}] failed to add worktree ${branchName}`)
      }
    }
  }
}

/**
 * Sync a git repository with its worktrees.
 * @param {Reporter} reporter
 * @param {IGitWorktreeConfig} config
 */
export async function sync_repo(reporter, config) {
  reporter.info(`[${config.main}] syncing...`)

  await sync_main_branch(reporter, config)
  await sync_worktrees(reporter, config, config.requiredBranches, true)
  await sync_worktrees(reporter, config, config.optionalBranches, false)

  reporter.info(`[${config.name}] done.`)
}
