export type GitReferenceKind = 'head' | 'localBranch' | 'remoteBranch' | 'tag' | 'other'

export interface IGitReference {
  readonly kind: GitReferenceKind
  readonly name: string
}

export interface IGitCommit {
  readonly hash: string
  readonly shortHash: string
  readonly parents: ReadonlyArray<string>
  readonly authorName: string
  readonly authoredAt: string
  readonly references: ReadonlyArray<IGitReference>
  readonly subject: string
}

export interface ICommitPage {
  readonly headCommit: string | null
  readonly commits: ReadonlyArray<IGitCommit>
  readonly hasMore: boolean
}
