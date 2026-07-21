import { Signal, type Event, type IDisposable } from '../core/signal'
import type { ICommitPage } from '../git/commit'
import { createCommitSearchQuery, type ICommitSearchQuery } from '../git/commit-search'
import type { ICommitHistorySnapshot } from './model'

const DEFAULT_PAGE_SIZE = 50
const MAX_COMMIT_LIMIT = 500

export interface ICommitHistorySource {
  listCommits(repositoryPath: string, limit: number, signal: AbortSignal): Promise<ICommitPage>
  searchCommits(
    repositoryPath: string,
    query: ICommitSearchQuery,
    limit: number,
    signal: AbortSignal,
  ): Promise<ICommitPage>
}

export class CommitHistorySession implements IDisposable {
  private readonly changeSignal = new Signal<ICommitHistorySnapshot | null>()
  private activeRequest: AbortController | null = null
  private currentSnapshot: ICommitHistorySnapshot | null = null
  private requestRevision = 0

  public readonly onDidChange: Event<ICommitHistorySnapshot | null> = this.changeSignal.event

  public constructor(
    private readonly historySource: ICommitHistorySource,
    private readonly pageSize = DEFAULT_PAGE_SIZE,
  ) {
    if (!Number.isSafeInteger(pageSize) || pageSize < 1 || pageSize > MAX_COMMIT_LIMIT) {
      throw new Error(`Commit page size must be between 1 and ${MAX_COMMIT_LIMIT}.`)
    }
  }

  public get snapshot(): ICommitHistorySnapshot | null {
    return this.currentSnapshot
  }

  public load(
    repositoryPath: string,
    signal?: AbortSignal,
  ): Promise<ICommitHistorySnapshot | null> {
    return this.loadWithLimit(repositoryPath, null, this.pageSize, signal)
  }

  public search(
    repositoryPath: string,
    query: ICommitSearchQuery,
    signal?: AbortSignal,
  ): Promise<ICommitHistorySnapshot | null> {
    return this.loadWithLimit(repositoryPath, createCommitSearchQuery(query), this.pageSize, signal)
  }

  public refresh(): Promise<ICommitHistorySnapshot | null> {
    const snapshot = this.currentSnapshot
    if (!snapshot) return Promise.resolve(null)
    return this.loadWithLimit(snapshot.repositoryPath, snapshot.searchQuery, snapshot.limit)
  }

  public loadMore(): Promise<ICommitHistorySnapshot | null> {
    const snapshot = this.currentSnapshot
    if (!snapshot || !snapshot.canLoadMore) return Promise.resolve(snapshot)
    const limit = Math.min(snapshot.limit + this.pageSize, MAX_COMMIT_LIMIT)
    if (limit === snapshot.limit) return Promise.resolve(snapshot)
    return this.loadWithLimit(snapshot.repositoryPath, snapshot.searchQuery, limit)
  }

  public clearSearch(signal?: AbortSignal): Promise<ICommitHistorySnapshot | null> {
    const snapshot = this.currentSnapshot
    if (!snapshot || !snapshot.searchQuery) return Promise.resolve(snapshot)
    return this.loadWithLimit(snapshot.repositoryPath, null, this.pageSize, signal)
  }

  public clear(): void {
    this.cancelActiveRequest()
    this.requestRevision += 1
    this.currentSnapshot = null
    this.changeSignal.emit(null)
  }

  public dispose(): void {
    this.clear()
    this.changeSignal.dispose()
  }

  private async loadWithLimit(
    repositoryPath: string,
    searchQuery: ICommitSearchQuery | null,
    limit: number,
    signal?: AbortSignal,
  ): Promise<ICommitHistorySnapshot | null> {
    this.cancelActiveRequest()
    const request = new AbortController()
    const revision = ++this.requestRevision
    this.activeRequest = request
    const cancelRequest = (): void => {
      if (revision === this.requestRevision) this.requestRevision += 1
      request.abort()
    }
    signal?.addEventListener('abort', cancelRequest, { once: true })

    try {
      if (signal?.aborted) cancelRequest()
      if (request.signal.aborted) return null

      const page = searchQuery
        ? await this.historySource.searchCommits(repositoryPath, searchQuery, limit, request.signal)
        : await this.historySource.listCommits(repositoryPath, limit, request.signal)
      if (revision !== this.requestRevision) return null

      const snapshot: ICommitHistorySnapshot = Object.freeze({
        revision,
        repositoryPath,
        headCommit: page.headCommit,
        searchQuery,
        commits: page.commits,
        hasMore: page.hasMore,
        canLoadMore: page.hasMore && limit < MAX_COMMIT_LIMIT,
        limit,
      })
      this.currentSnapshot = snapshot
      this.changeSignal.emit(snapshot)
      return snapshot
    } catch (cause) {
      request.abort()
      if (revision !== this.requestRevision) return null
      throw cause
    } finally {
      signal?.removeEventListener('abort', cancelRequest)
      if (this.activeRequest === request) this.activeRequest = null
    }
  }

  private cancelActiveRequest(): void {
    this.activeRequest?.abort()
    this.activeRequest = null
  }
}
