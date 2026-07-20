export interface IGitCommit {
  readonly hash: string
  readonly shortHash: string
  readonly parents: ReadonlyArray<string>
  readonly authorName: string
  readonly authoredAt: string
  readonly subject: string
}

export interface ICommitPage {
  readonly commits: ReadonlyArray<IGitCommit>
  readonly hasMore: boolean
}
