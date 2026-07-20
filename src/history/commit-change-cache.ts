import type { IDisposable } from '../core/signal'
import type { IFileChange } from '../git/file-change'

const DEFAULT_MAX_ENTRIES = 200

export interface ICommitChangeSource {
  listCommitChanges(
    repositoryPath: string,
    commit: string,
    parentCommit: string | null,
  ): Promise<ReadonlyArray<IFileChange>>
}

export class CommitChangeCache implements IDisposable {
  private readonly entries = new Map<string, Promise<ReadonlyArray<IFileChange>>>()

  public constructor(
    private readonly changeSource: ICommitChangeSource,
    private readonly maxEntries = DEFAULT_MAX_ENTRIES,
  ) {
    if (!Number.isSafeInteger(maxEntries) || maxEntries < 1) {
      throw new Error('Commit change cache size must be a positive integer.')
    }
  }

  public getChanges(
    repositoryPath: string,
    commit: string,
    parentCommit: string | null,
  ): Promise<ReadonlyArray<IFileChange>> {
    const cacheKey = JSON.stringify([repositoryPath, commit, parentCommit])
    const cached = this.entries.get(cacheKey)
    if (cached) {
      this.entries.delete(cacheKey)
      this.entries.set(cacheKey, cached)
      return cached
    }

    const request = this.changeSource
      .listCommitChanges(repositoryPath, commit, parentCommit)
      .then(changes => Object.freeze(changes.map(change => Object.freeze({ ...change }))))
    this.entries.set(cacheKey, request)
    this.evictOverflow()
    void request.catch(() => {
      if (this.entries.get(cacheKey) === request) this.entries.delete(cacheKey)
    })
    return request
  }

  public clear(): void {
    this.entries.clear()
  }

  public dispose(): void {
    this.clear()
  }

  private evictOverflow(): void {
    if (this.entries.size <= this.maxEntries) return
    const oldestKey = this.entries.keys().next().value
    if (oldestKey !== undefined) this.entries.delete(oldestKey)
  }
}
