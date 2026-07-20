import { execFile } from 'node:child_process'
import path from 'node:path'
import type { IFileChange } from './file-change'
import { parseNameStatus } from './name-status'

const GIT_TIMEOUT_MS = 15_000
const MAX_COMMAND_OUTPUT_BYTES = 16 * 1024 * 1024

export class GitBlobDisplayError extends Error {}

export class GitClient {
  public async resolveRepository(candidatePath: string): Promise<string> {
    const output = await runGit(candidatePath, ['rev-parse', '--show-toplevel'])
    return path.resolve(output.toString('utf8').trim())
  }

  public async resolveCommit(repositoryPath: string, reference: string): Promise<string> {
    const value = reference.trim()
    if (!value || value.length > 1024 || value.includes('\0')) {
      throw new Error('Git reference is invalid.')
    }

    const output = await runGit(repositoryPath, [
      'rev-parse',
      '--verify',
      '--end-of-options',
      `${value}^{commit}`,
    ])
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
  ): Promise<ReadonlyArray<IFileChange>> {
    assertResolvedCommit(baseCommit)
    assertResolvedCommit(targetCommit)
    const output = await runGit(repositoryPath, [
      'diff',
      '--name-status',
      '-z',
      '--find-renames',
      baseCommit,
      targetCommit,
      '--',
    ])
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
    const sizeOutput = await runGit(repositoryPath, ['cat-file', '-s', object], signal)
    const size = Number(sizeOutput.toString('utf8').trim())
    if (!Number.isSafeInteger(size) || size < 0) {
      throw new Error('Git returned an invalid blob size.')
    }
    if (size > maxBytes) {
      throw new GitBlobDisplayError(
        `File is ${formatBytes(size)}; the configured display limit is ${formatBytes(maxBytes)}.`,
      )
    }

    const contents = await runGit(
      repositoryPath,
      ['cat-file', 'blob', object],
      signal,
      Math.max(maxBytes + 1024, 64 * 1024),
    )
    if (isProbablyBinary(contents)) {
      throw new GitBlobDisplayError('Binary file content is not displayed by VSGit.')
    }
    return contents.toString('utf8')
  }
}

function runGit(
  repositoryPath: string,
  args: ReadonlyArray<string>,
  signal?: AbortSignal,
  maxBuffer = MAX_COMMAND_OUTPUT_BYTES,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    execFile(
      'git',
      ['-C', repositoryPath, ...args],
      {
        encoding: 'buffer',
        maxBuffer,
        signal,
        timeout: GIT_TIMEOUT_MS,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        if (!error) {
          resolve(stdout)
          return
        }

        const detail = stderr.toString('utf8').trim()
        reject(new Error(detail || error.message, { cause: error }))
      },
    )
  })
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
