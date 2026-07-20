import type { IGitCommit } from '../git/commit'
import { isFileChange, type IFileChange } from '../git/file-change'
import type { ICommitHistorySnapshot } from '../history/model'
import { buildChangeTree, type IChangeTreeNode } from './change-tree'

export interface ICommitDiffContext {
  readonly historyRevision: number
  readonly repositoryPath: string
  readonly commit: IGitCommit
  readonly parentCommit: string | null
}

export interface ICommitNode {
  readonly kind: 'commit'
  readonly context: ICommitDiffContext
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
  const nodes: ICommitTreeNode[] = snapshot.commits.map(commit => ({
    kind: 'commit',
    context: Object.freeze({
      historyRevision: snapshot.revision,
      repositoryPath: snapshot.repositoryPath,
      commit,
      parentCommit: commit.parents[0] ?? null,
    }),
  }))
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
  return node.kind === 'commit' && isCommitDiffContext(node.context)
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
  return {
    kind: 'commit-directory',
    name: node.name,
    path: node.path,
    context,
    children: node.children.map(child => attachCommitContext(context, child)),
  }
}
