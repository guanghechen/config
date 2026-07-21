import type { IGitCommit } from '../git/commit'
import type { ICommitSearchQuery } from '../git/commit-search'

export interface ICommitHistorySnapshot {
  readonly revision: number
  readonly repositoryPath: string
  readonly headCommit: string | null
  readonly searchQuery: ICommitSearchQuery | null
  readonly commits: ReadonlyArray<IGitCommit>
  readonly hasMore: boolean
  readonly canLoadMore: boolean
  readonly limit: number
}
