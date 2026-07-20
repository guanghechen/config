import type { IGitCommit } from '../git/commit'
import { isFileChange, type IFileChange } from '../git/file-change'
import type { ICommitHistorySnapshot } from '../history/model'
import { buildCommitGraphRows, type ICommitGraphRow } from '../history/commit-graph'
import { buildChangeTree, type IChangeTreeNode, type IDirectoryNode } from './change-tree'

export interface ICommitDiffContext {
  readonly historyRevision: number
  readonly repositoryPath: string
  readonly commit: IGitCommit
  readonly parentCommit: string | null
}

export interface ICommitNode {
  readonly kind: 'commit'
  readonly context: ICommitDiffContext
  readonly graph: ICommitGraphRow
}

export interface ICommitDirectoryNode {
  readonly kind: 'commit-directory'
  readonly name: string
  readonly path: string
  readonly context: ICommitDiffContext
  readonly children: ReadonlyArray<ICommitChangeNode>
}

export interface ICommitFileNode {
  readonly kind: 'commit-file'
  readonly name: string
  readonly path: string
  readonly context: ICommitDiffContext
  readonly change: IFileChange
}

export interface ICommitErrorNode {
  readonly kind: 'commit-error'
  readonly commitHash: string
  readonly message: string
}

export interface ILoadMoreCommitsNode {
  readonly kind: 'load-more-commits'
  readonly historyRevision: number
}

export type ICommitChangeNode = ICommitDirectoryNode | ICommitFileNode
export type ICommitTreeNode =
  ICommitNode | ICommitChangeNode | ICommitErrorNode | ILoadMoreCommitsNode

export function createCommitRootNodes(
  snapshot: ICommitHistorySnapshot,
): ReadonlyArray<ICommitTreeNode> {
  const graphRows = buildCommitGraphRows(snapshot.commits)
  const nodes: ICommitTreeNode[] = snapshot.commits.map((commit, index) => {
    const graph = graphRows[index]
    if (!graph) throw new Error('Commit graph is incomplete.')
    return {
      kind: 'commit',
      context: Object.freeze({
        historyRevision: snapshot.revision,
        repositoryPath: snapshot.repositoryPath,
        commit,
        parentCommit: commit.parents[0] ?? null,
      }),
      graph,
    }
  })
  if (snapshot.hasMore) {
    nodes.push({ kind: 'load-more-commits', historyRevision: snapshot.revision })
  }
  return nodes
}

export function buildCommitChangeTree(
  context: ICommitDiffContext,
  changes: ReadonlyArray<IFileChange>,
): ReadonlyArray<ICommitChangeNode> {
  return buildChangeTree(changes).map(node => attachCommitContext(context, node))
}

export function isCommitNode(value: unknown): value is ICommitNode {
  if (!value || typeof value !== 'object') return false
  const node = value as Partial<ICommitNode>
  return node.kind === 'commit' && isCommitDiffContext(node.context) && isCommitGraphRow(node.graph)
}

function isCommitGraphRow(value: unknown): value is ICommitGraphRow {
  if (!value || typeof value !== 'object') return false
  const row = value as Partial<ICommitGraphRow>
  return (
    typeof row.commitHash === 'string' &&
    Number.isSafeInteger(row.lane) &&
    Number.isSafeInteger(row.laneCount) &&
    Number.isSafeInteger(row.parentCount)
  )
}

export function isCommitFileNode(value: unknown): value is ICommitFileNode {
  if (!value || typeof value !== 'object') return false
  const node = value as Partial<ICommitFileNode>
  return (
    node.kind === 'commit-file' &&
    typeof node.name === 'string' &&
    typeof node.path === 'string' &&
    isFileChange(node.change) &&
    isCommitDiffContext(node.context)
  )
}

function isCommitDiffContext(value: unknown): value is ICommitDiffContext {
  if (!value || typeof value !== 'object') return false
  const context = value as Partial<ICommitDiffContext>
  return (
    Number.isSafeInteger(context.historyRevision) &&
    typeof context.repositoryPath === 'string' &&
    typeof context.commit?.hash === 'string' &&
    typeof context.commit.shortHash === 'string' &&
    (context.parentCommit === null || typeof context.parentCommit === 'string')
  )
}

function attachCommitContext(
  context: ICommitDiffContext,
  node: IChangeTreeNode,
): ICommitChangeNode {
  if (node.kind === 'file') {
    return {
      kind: 'commit-file',
      name: node.name,
      path: node.path,
      context,
      change: node.change,
    }
  }

  const compacted = compactDirectory(node)
  return {
    kind: 'commit-directory',
    name: compacted.name,
    path: compacted.path,
    context,
    children: compacted.children.map(child => attachCommitContext(context, child)),
  }
}

function compactDirectory(node: IDirectoryNode): IDirectoryNode {
  const names = [node.name]
  let tail = node

  while (tail.children.length === 1) {
    const child = tail.children[0]
    if (child?.kind !== 'directory') break
    names.push(child.name)
    tail = child
  }

  return {
    kind: 'directory',
    name: names.join('/'),
    path: tail.path,
    children: tail.children,
  }
}
