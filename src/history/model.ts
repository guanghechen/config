import type { IGitCommit } from '../git/commit'

export interface ICommitHistorySnapshot {
  readonly revision: number
  readonly repositoryPath: string
  readonly commits: ReadonlyArray<IGitCommit>
  readonly hasMore: boolean
  readonly limit: number
}
