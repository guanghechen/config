import type { IFileChange } from '../git/file-change'

export interface IRevisionComparison {
  readonly repositoryPath: string
  readonly baseRef: string
  readonly targetRef: string
  readonly baseCommit: string
  readonly targetCommit: string
}

export interface ICompareSnapshot extends IRevisionComparison {
  readonly revision: number
  readonly changes: ReadonlyArray<IFileChange>
}
