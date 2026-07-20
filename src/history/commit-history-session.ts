import { EventEmitter, type Disposable, type Event } from 'vscode'
import { GitClient } from '../git/git-client'
import type { ICommitHistorySnapshot } from './model'

const DEFAULT_PAGE_SIZE = 50
const MAX_COMMIT_LIMIT = 500

export class CommitHistorySession implements Disposable {
  private readonly changeEmitter = new EventEmitter<ICommitHistorySnapshot | null>()
  private operationRevision = 0
  private value: ICommitHistorySnapshot | null = null

  public readonly onDidChange: Event<ICommitHistorySnapshot | null> = this.changeEmitter.event

  public constructor(
    private readonly gitClient: GitClient,
    private readonly pageSize = DEFAULT_PAGE_SIZE,
  ) {
    if (!Number.isSafeInteger(pageSize) || pageSize < 1 || pageSize > MAX_COMMIT_LIMIT) {
      throw new Error(`Commit page size must be between 1 and ${MAX_COMMIT_LIMIT}.`)
    }
  }

  public get snapshot(): ICommitHistorySnapshot | null {
    return this.value
  }

  public load(repositoryPath: string): Promise<ICommitHistorySnapshot | null> {
    return this.loadWithLimit(repositoryPath, this.pageSize)
  }

  public refresh(): Promise<ICommitHistorySnapshot | null> {
    const snapshot = this.value
    if (!snapshot) return Promise.resolve(null)
    return this.loadWithLimit(snapshot.repositoryPath, snapshot.limit)
  }

  public loadMore(): Promise<ICommitHistorySnapshot | null> {
    const snapshot = this.value
    if (!snapshot || !snapshot.hasMore) return Promise.resolve(snapshot)
    const limit = Math.min(snapshot.limit + this.pageSize, MAX_COMMIT_LIMIT)
    if (limit === snapshot.limit) return Promise.resolve(snapshot)
    return this.loadWithLimit(snapshot.repositoryPath, limit)
  }

  public clear(): void {
    this.operationRevision += 1
    this.value = null
    this.changeEmitter.fire(null)
  }

  public dispose(): void {
    this.clear()
    this.changeEmitter.dispose()
  }

  private async loadWithLimit(
    repositoryPath: string,
    limit: number,
  ): Promise<ICommitHistorySnapshot | null> {
    const revision = ++this.operationRevision
    const page = await this.gitClient.listCommits(repositoryPath, limit)
    if (revision !== this.operationRevision) return null

    const snapshot: ICommitHistorySnapshot = Object.freeze({
      revision,
      repositoryPath,
      commits: page.commits,
      hasMore: page.hasMore && limit < MAX_COMMIT_LIMIT,
      limit,
    })
    this.value = snapshot
    this.changeEmitter.fire(snapshot)
    return snapshot
  }
}
