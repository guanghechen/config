import path from 'node:path'
import type { ICommitPage } from './commit'
import { parseCommitLog } from './commit-log'
import {
  createCommitSearchArguments,
  createCommitSearchQuery,
  type ICommitSearchQuery,
} from './commit-search'
import type { IFileChange } from './file-change'
import { GitCommandError, GitRunner, type IGitRunner } from './git-runner'
import { parseNameStatus } from './name-status'

const MAX_COMMIT_PAGE_SIZE = 500
const NAME_STATUS_ARGS = ['--name-status', '-z', '--find-renames', '--find-copies'] as const
const COMMIT_LOG_FORMAT = '--format=%H%x00%h%x00%P%x00%an%x00%aI%x00%D%x00%s%x00'

export class GitBlobDisplayError extends Error {}

export class GitClient {
  public constructor(private readonly gitRunner: IGitRunner = new GitRunner()) {}

  public async resolveRepository(candidatePath: string, signal?: AbortSignal): Promise<string> {
    const output = await this.gitRunner.run(candidatePath, ['rev-parse', '--show-toplevel'], {
      signal,
    })
    return path.resolve(output.toString('utf8').trim())
  }

  public async resolveCommit(
    repositoryPath: string,
    reference: string,
    signal?: AbortSignal,
  ): Promise<string> {
    const value = reference.trim()
    if (!value || value.length > 1024 || value.includes('\0')) {
      throw new Error('Git reference is invalid.')
    }

    const output = await this.gitRunner.run(
      repositoryPath,
      ['rev-parse', '--verify', '--end-of-options', `${value}^{commit}`],
      { signal },
    )
    const commit = output.toString('utf8').trim()
    if (!/^[0-9a-f]{40,64}$/i.test(commit)) {
      throw new Error(`Git did not resolve "${value}" to a commit.`)
    }
    return commit
  }

  public async listChanges(
    repositoryPath: string,
    baseCommit: string,
    targetCommit: string,
    signal?: AbortSignal,
  ): Promise<ReadonlyArray<IFileChange>> {
    assertResolvedCommit(baseCommit)
    assertResolvedCommit(targetCommit)
    const output = await this.gitRunner.run(
      repositoryPath,
      ['diff', ...NAME_STATUS_ARGS, baseCommit, targetCommit, '--'],
      { signal },
    )
    return parseNameStatus(output)
  }

  public async listCommits(
    repositoryPath: string,
    limit: number,
    signal?: AbortSignal,
  ): Promise<ICommitPage> {
    assertCommitLimit(limit)
    const headCommit = await resolveOptionalHead(this.gitRunner, repositoryPath, signal)
    if (!headCommit) {
      return Object.freeze({
        headCommit: null,
        commits: Object.freeze([]),
        hasMore: false,
      })
    }

    return this.loadCommitPage(repositoryPath, headCommit, [], [headCommit], [], limit, signal)
  }

  public async searchCommits(
    repositoryPath: string,
    queryValue: ICommitSearchQuery,
    limit: number,
    signal?: AbortSignal,
  ): Promise<ICommitPage> {
    assertCommitLimit(limit)
    const query = createCommitSearchQuery(queryValue)
    const headCommit = await resolveOptionalHead(this.gitRunner, repositoryPath, signal)
    const search = createCommitSearchArguments(query, headCommit)
    if (query.scope.kind === 'head' && !headCommit) {
      return Object.freeze({
        headCommit: null,
        commits: Object.freeze([]),
        hasMore: false,
      })
    }

    return this.loadCommitPage(
      repositoryPath,
      headCommit,
      search.options,
      search.revisions,
      search.pathspecs,
      limit,
      signal,
    )
  }

  public async listCommitChanges(
    repositoryPath: string,
    commit: string,
    parentCommit: string | null,
    signal?: AbortSignal,
  ): Promise<ReadonlyArray<IFileChange>> {
    assertResolvedCommit(commit)
    if (parentCommit) {
      assertResolvedCommit(parentCommit)
      return this.listChanges(repositoryPath, parentCommit, commit, signal)
    }

    const output = await this.gitRunner.run(
      repositoryPath,
      ['diff-tree', '--root', '--no-commit-id', ...NAME_STATUS_ARGS, '-r', commit, '--'],
      { signal },
    )
    return parseNameStatus(output)
  }

  public async readTextFile(
    repositoryPath: string,
    commit: string,
    filePath: string,
    maxBytes: number,
    signal?: AbortSignal,
  ): Promise<string> {
    assertResolvedCommit(commit)
    if (!filePath || filePath.includes('\0')) throw new Error('Git file path is invalid.')

    const object = `${commit}:${filePath}`
    const sizeOutput = await this.gitRunner.run(repositoryPath, ['cat-file', '-s', object], {
      signal,
    })
    const size = Number(sizeOutput.toString('utf8').trim())
    if (!Number.isSafeInteger(size) || size < 0) {
      throw new Error('Git returned an invalid blob size.')
    }
    if (size > maxBytes) {
      throw new GitBlobDisplayError(
        `File is ${formatBytes(size)}; the configured display limit is ${formatBytes(maxBytes)}.`,
      )
    }

    const contents = await this.gitRunner.run(repositoryPath, ['cat-file', 'blob', object], {
      signal,
      maxBuffer: Math.max(maxBytes + 1024, 64 * 1024),
    })
    if (isProbablyBinary(contents)) {
      throw new GitBlobDisplayError('Binary file content is not displayed by VSGit.')
    }
    return contents.toString('utf8')
  }

  private async loadCommitPage(
    repositoryPath: string,
    headCommit: string | null,
    options: ReadonlyArray<string>,
    revisions: ReadonlyArray<string>,
    pathspecs: ReadonlyArray<string>,
    limit: number,
    signal?: AbortSignal,
  ): Promise<ICommitPage> {
    const output = await this.gitRunner.run(
      repositoryPath,
      [
        'log',
        '--topo-order',
        '--decorate=full',
        '-z',
        `--max-count=${limit + 1}`,
        COMMIT_LOG_FORMAT,
        ...options,
        ...revisions,
        '--',
        ...pathspecs,
      ],
      { signal },
    )
    const commits = parseCommitLog(output)
    return Object.freeze({
      headCommit,
      commits: Object.freeze(commits.slice(0, limit)),
      hasMore: commits.length > limit,
    })
  }
}

function assertCommitLimit(value: number): void {
  if (!Number.isSafeInteger(value) || value < 1 || value > MAX_COMMIT_PAGE_SIZE) {
    throw new Error(`Commit page size must be between 1 and ${MAX_COMMIT_PAGE_SIZE}.`)
  }
}

async function resolveOptionalHead(
  gitRunner: IGitRunner,
  repositoryPath: string,
  signal?: AbortSignal,
): Promise<string | null> {
  let output: Buffer
  try {
    output = await gitRunner.run(
      repositoryPath,
      ['rev-parse', '--verify', '--quiet', '--end-of-options', 'HEAD^{commit}'],
      { signal },
    )
  } catch (cause) {
    if (cause instanceof GitCommandError && cause.exitCode === 1) return null
    throw cause
  }

  const commit = output.toString('utf8').trim()
  if (!/^[0-9a-f]{40,64}$/i.test(commit)) {
    throw new Error('Git did not resolve HEAD to a commit.')
  }
  return commit
}

function assertResolvedCommit(value: string): void {
  if (!/^[0-9a-f]{40,64}$/i.test(value)) throw new Error('Resolved commit is invalid.')
}

function isProbablyBinary(contents: Buffer): boolean {
  const sample = contents.subarray(0, Math.min(contents.length, 8192))
  if (sample.includes(0)) return true
  if (sample.length === 0) return false

  let controlBytes = 0
  for (const byte of sample) {
    if (byte < 7 || (byte > 13 && byte < 32)) controlBytes += 1
  }
  return controlBytes / sample.length > 0.1
}

function formatBytes(value: number): string {
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KiB`
  return `${(value / (1024 * 1024)).toFixed(1)} MiB`
}
