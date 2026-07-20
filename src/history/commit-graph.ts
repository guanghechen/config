import type { IGitCommit } from '../git/commit'

export interface ICommitGraphRow {
  readonly commitHash: string
  readonly lane: number
  readonly laneCount: number
  readonly parentCount: number
}

export function buildCommitGraphRows(
  commits: ReadonlyArray<IGitCommit>,
): ReadonlyArray<ICommitGraphRow> {
  const lanes: string[] = []
  const rows: ICommitGraphRow[] = []

  for (const commit of commits) {
    let lane = lanes.indexOf(commit.hash)
    if (lane < 0) {
      lanes.unshift(commit.hash)
      lane = 0
    }

    rows.push(
      Object.freeze({
        commitHash: commit.hash,
        lane,
        laneCount: lanes.length,
        parentCount: commit.parents.length,
      }),
    )
    replaceLaneWithParents(lanes, lane, commit.parents)
  }

  return Object.freeze(rows)
}

function replaceLaneWithParents(
  lanes: string[],
  lane: number,
  parents: ReadonlyArray<string>,
): void {
  lanes.splice(lane, 1)

  const newParents: string[] = []
  for (const parent of parents) {
    if (!lanes.includes(parent) && !newParents.includes(parent)) newParents.push(parent)
  }
  lanes.splice(Math.min(lane, lanes.length), 0, ...newParents)
}
