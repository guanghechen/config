import { execFile } from 'node:child_process'
import { isAbortError } from '../core/cancellation'

const GIT_TIMEOUT_MS = 15_000
const MAX_GIT_OUTPUT_BYTES = 16 * 1024 * 1024

export interface IGitRunOptions {
  readonly maxBuffer?: number
  readonly signal?: AbortSignal
}

export interface IGitRunner {
  run(
    repositoryPath: string,
    args: ReadonlyArray<string>,
    options?: IGitRunOptions,
  ): Promise<Buffer>
}

export class GitCommandError extends Error {
  public constructor(
    message: string,
    public readonly exitCode: number | null,
    cause: Error,
  ) {
    super(message, { cause })
  }
}

export class GitRunner implements IGitRunner {
  public run(
    repositoryPath: string,
    args: ReadonlyArray<string>,
    options: IGitRunOptions = {},
  ): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      execFile(
        'git',
        ['-C', repositoryPath, ...args],
        {
          encoding: 'buffer',
          maxBuffer: options.maxBuffer ?? MAX_GIT_OUTPUT_BYTES,
          signal: options.signal,
          timeout: GIT_TIMEOUT_MS,
          windowsHide: true,
        },
        (error, stdout, stderr) => {
          if (!error) {
            resolve(stdout)
            return
          }
          if (options.signal?.aborted || isAbortError(error)) {
            reject(error)
            return
          }

          const detail = stderr.toString('utf8').trim()
          reject(
            new GitCommandError(
              detail || error.message,
              typeof error.code === 'number' ? error.code : null,
              error,
            ),
          )
        },
      )
    })
  }
}
