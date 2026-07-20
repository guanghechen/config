import type { IGitCommit } from '../git/commit'

export interface IOrderedCommitPair {
  readonly base: IGitCommit
  readonly target: IGitCommit
}

export function orderCommitsForComparison(
  history: ReadonlyArray<IGitCommit>,
  selected: ReadonlyArray<IGitCommit>,
): IOrderedCommitPair | null {
  const left = selected[0]
  const right = selected[1]
  if (!left || !right || selected.length !== 2 || left.hash === right.hash) return null

  const leftIndex = history.findIndex(commit => commit.hash === left.hash)
  const rightIndex = history.findIndex(commit => commit.hash === right.hash)
  if (leftIndex < 0 || rightIndex < 0 || leftIndex === rightIndex) return null

  return leftIndex > rightIndex ? { base: left, target: right } : { base: right, target: left }
}
