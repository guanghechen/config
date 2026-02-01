#!/usr/bin/env node

/**
 * Sync XDG config repositories using git worktrees.
 */

import fs from 'node:fs'
import { Command } from '@guanghechen/stl/commander'
import { Reporter } from '@guanghechen/stl/reporter'
import {
  XDG_CONFIG_HOME,
  XDG_CONFIG_NODE_ASSET_REPO_CONFIG,
  XDG_CONFIG_NODE_ASSET_REPO_LOCAL_CONFIG,
} from '#src/env/path'
import { settings } from '#src/env/setting'
import { sync_repo } from '#src/util/git'

/** @typedef {import('#src/env/setting').IEdition} IEdition */
/** @typedef {import('#src/util/git').IGitWorktreeConfig} IGitWorktreeConfig */

/**
 * @typedef {Object} IRepoDefinition
 * @property {string} root - Root directory for worktrees (supports ${VAR} syntax)
 * @property {string} main - Main repository path (supports ${VAR} syntax)
 * @property {string} url - Git repository URL
 * @property {string} name - Repository name for logging
 * @property {string} branch - Main branch name
 * @property {string[]} branches - All branches we care about (supports `:` syntax)
 * @property {Record<IEdition, string[]>} editions - Required branches per edition (branch names only)
 */

/**
 * @typedef {Object} IRepoConfig
 * @property {IRepoDefinition[]} repos
 */

const reporter = new Reporter({ prefix: 'sync-xdg-config' })

/**
 * Expand environment variables in string.
 * @param {string} str
 * @returns {string}
 */
function expandVars(str) {
  return str.replace(/\$\{(\w+)\}/g, (_, name) => {
    if (name === 'HOME') return process.env.HOME ?? ''
    if (name === 'XDG_CONFIG_HOME') return XDG_CONFIG_HOME
    return process.env[name] ?? ''
  })
}

/**
 * Load and merge repo configurations.
 * @returns {IRepoDefinition[]}
 */
function loadRepoDefinitions() {
  /** @type {IRepoConfig} */
  let config = { repos: [] }

  if (fs.existsSync(XDG_CONFIG_NODE_ASSET_REPO_CONFIG)) {
    const content = fs.readFileSync(XDG_CONFIG_NODE_ASSET_REPO_CONFIG, 'utf8')
    config = JSON.parse(content)
  }

  if (fs.existsSync(XDG_CONFIG_NODE_ASSET_REPO_LOCAL_CONFIG)) {
    const localContent = fs.readFileSync(XDG_CONFIG_NODE_ASSET_REPO_LOCAL_CONFIG, 'utf8')
    /** @type {IRepoConfig} */
    const localConfig = JSON.parse(localContent)

    // Merge: local repos override by name, or append if new
    const repoMap = new Map(config.repos.map(r => [r.name, r]))
    for (const repo of localConfig.repos) {
      repoMap.set(repo.name, repo)
    }
    config.repos = Array.from(repoMap.values())
  }

  // Expand variables in paths
  return config.repos.map(repo => ({
    ...repo,
    root: expandVars(repo.root),
    main: expandVars(repo.main),
  }))
}

/**
 * Convert repo definition to git worktree config based on edition.
 * @param {IRepoDefinition} def
 * @param {IEdition} edition
 * @returns {IGitWorktreeConfig}
 */
function toGitWorktreeConfig(def, edition) {
  const requiredNames = new Set(def.editions[edition] ?? [])

  /** @type {string[]} */
  const requiredBranches = []
  /** @type {string[]} */
  const optionalBranches = []

  for (const branch of def.branches) {
    const name = branch.split(':')[0]
    if (requiredNames.has(name)) {
      requiredBranches.push(branch)
    } else {
      optionalBranches.push(branch)
    }
  }

  return {
    root: def.root,
    main: def.main,
    url: def.url,
    name: def.name,
    branch: def.branch,
    requiredBranches,
    optionalBranches,
  }
}

/**
 * @param {IEdition} edition
 */
export async function handleSyncXdgConfig(edition) {
  const definitions = loadRepoDefinitions()
  for (const def of definitions) {
    const config = toGitWorktreeConfig(def, edition)
    await sync_repo(reporter, config)
  }
}

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command('sync-xdg-config', reporter)
    .description('Sync XDG config repositories using git worktrees.')
    .option('--edition <edition>', 'Override edition (nix, nix-remote, osx, win)')
    .example('sync-xdg-config')
    .example('sync-xdg-config --edition osx')
    .action(async ({ opts }) => {
      const editionArg = /** @type {IEdition | undefined} */ (opts.edition)
      const data = await settings.load()
      const edition = editionArg ?? data.edition
      reporter.info(`Using edition: ${edition}`)
      await handleSyncXdgConfig(edition)
    })

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
