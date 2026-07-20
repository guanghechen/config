import {
  Disposable,
  EventEmitter,
  ThemeColor,
  ThemeIcon,
  TreeItem,
  TreeItemCollapsibleState,
  type Event,
  type TreeDataProvider,
} from 'vscode'
import { CommitChangeCache } from '../../history/commit-change-cache'
import { CommitHistorySession } from '../../history/commit-history-session'
import { CommitMarkSession } from '../../history/commit-mark-session'
import { COMMAND_IDS, VIEW_ITEM_CONTEXT_VALUES } from '../../platform/extension-ids'
import {
  buildCommitChangeTree,
  createCommitRootNodes,
  type ICommitFileNode,
  type ICommitNode,
  type ICommitTreeNode,
} from './tree'
import {
  formatCommitGraphPrefix,
  formatCommitReferenceSummary,
  formatCommitReferenceTooltip,
  resolveCommitGraphColorId,
} from './graph-presentation'
import { createFileChangeDescription, createFileChangeTooltip } from '../file-change/presentation'
import { createRepositoryResourceUri } from '../file-change/resource'
import { formatCommitSubject } from './subject'

export class CommitHistoryTreeProvider implements TreeDataProvider<ICommitTreeNode>, Disposable {
  private readonly changeEmitter = new EventEmitter<ICommitTreeNode | undefined>()
  private readonly subscriptions: Disposable
  private rootNodes: ReadonlyArray<ICommitTreeNode> = []

  public readonly onDidChangeTreeData: Event<ICommitTreeNode | undefined> = this.changeEmitter.event

  public constructor(
    private readonly changeCache: CommitChangeCache,
    private readonly markSession: CommitMarkSession,
    private readonly historySession: CommitHistorySession,
  ) {
    this.subscriptions = Disposable.from(
      this.historySession.onDidChange(snapshot => {
        this.rootNodes = snapshot ? createCommitRootNodes(snapshot) : []
        this.changeEmitter.fire(undefined)
      }),
      this.markSession.onDidChange(() => this.changeEmitter.fire(undefined)),
    )
    const snapshot = this.historySession.snapshot
    this.rootNodes = snapshot ? createCommitRootNodes(snapshot) : []
  }

  public getTreeItem(node: ICommitTreeNode): TreeItem {
    switch (node.kind) {
      case 'commit':
        return createCommitTreeItem(
          node,
          this.markSession.isMarked(node.context.repositoryPath, node.context.commit.hash),
        )
      case 'commit-directory': {
        const item = new TreeItem(node.name, TreeItemCollapsibleState.Expanded)
        item.id = `commit-directory:${node.context.commit.hash}:${node.path}`
        item.contextValue = VIEW_ITEM_CONTEXT_VALUES.commitDirectory
        item.resourceUri = createRepositoryResourceUri(node.context.repositoryPath, node.path)
        item.tooltip = node.path
        return item
      }
      case 'commit-file':
        return createCommitFileTreeItem(node)
      case 'commit-error': {
        const item = new TreeItem('Unable to load commit changes', TreeItemCollapsibleState.None)
        item.id = `commit-error:${node.commitHash}`
        item.contextValue = VIEW_ITEM_CONTEXT_VALUES.commitError
        item.description = node.message
        item.iconPath = new ThemeIcon('error')
        item.tooltip = node.message
        return item
      }
      case 'load-more-commits': {
        const item = new TreeItem('Load more commits…', TreeItemCollapsibleState.None)
        item.id = `load-more-commits:${node.historyRevision}`
        item.contextValue = VIEW_ITEM_CONTEXT_VALUES.loadMoreCommits
        item.iconPath = new ThemeIcon('unfold')
        item.command = { command: COMMAND_IDS.loadMoreCommits, title: 'Load More Commits' }
        return item
      }
    }
  }

  public getChildren(node?: ICommitTreeNode): ICommitTreeNode[] | Promise<ICommitTreeNode[]> {
    if (!node) {
      return [...this.rootNodes]
    }
    if (node.kind === 'commit') return this.getCommitChildren(node)
    if (node.kind === 'commit-directory') return [...node.children]
    return []
  }

  public dispose(): void {
    this.subscriptions.dispose()
    this.changeEmitter.dispose()
  }

  private async getCommitChildren(node: ICommitNode): Promise<ICommitTreeNode[]> {
    try {
      const changes = await this.changeCache.getChanges(
        node.context.repositoryPath,
        node.context.commit.hash,
        node.context.parentCommit,
      )
      if (this.historySession.snapshot?.revision !== node.context.historyRevision) return []
      return [...buildCommitChangeTree(node.context, changes)]
    } catch (cause) {
      return [
        {
          kind: 'commit-error',
          commitHash: node.context.commit.hash,
          message: cause instanceof Error ? cause.message : 'Git failed to load this commit.',
        },
      ]
    }
  }
}

function createCommitTreeItem(node: ICommitNode, marked: boolean): TreeItem {
  const { commit } = node.context
  const subject = formatCommitSubject(commit.subject) || '(no commit message)'
  const graphPrefix = formatCommitGraphPrefix(node.graph)
  const item = new TreeItem(
    graphPrefix ? `${graphPrefix}  ${subject}` : subject,
    TreeItemCollapsibleState.Collapsed,
  )
  item.id = `commit:${commit.hash}`
  item.contextValue = marked
    ? VIEW_ITEM_CONTEXT_VALUES.commitMarked
    : VIEW_ITEM_CONTEXT_VALUES.commit
  const references = formatCommitReferenceSummary(commit.references)
  item.description = [marked ? 'Marked' : '', references, commit.authorName || 'Unknown author']
    .filter(Boolean)
    .join(' · ')
  item.iconPath = new ThemeIcon(
    marked ? 'bookmark' : 'git-commit',
    new ThemeColor(resolveCommitGraphColorId(node.graph.lane)),
  )
  const referenceTooltip = formatCommitReferenceTooltip(commit.references)
  item.tooltip = [
    commit.subject || '(no commit message)',
    '',
    ...(marked ? ['Marked for comparison', ''] : []),
    ...(referenceTooltip ? [referenceTooltip, ''] : []),
    commit.hash,
    `Author: ${commit.authorName || 'Unknown author'}`,
    `Date: ${new Date(commit.authoredAt).toLocaleString()}`,
  ].join('\n')
  return item
}

function createCommitFileTreeItem(node: ICommitFileNode): TreeItem {
  const item = new TreeItem(node.name, TreeItemCollapsibleState.None)
  item.id = `commit-file:${node.context.commit.hash}:${node.change.status}:${node.path}`
  item.contextValue = VIEW_ITEM_CONTEXT_VALUES.commitFile
  item.description = createFileChangeDescription(node.change)
  item.resourceUri = createRepositoryResourceUri(
    node.context.repositoryPath,
    node.path,
    node.change.kind,
  )
  item.tooltip = createFileChangeTooltip(node.change)
  item.command = {
    command: COMMAND_IDS.openCommitFileDiff,
    title: 'Open Commit File Diff',
    arguments: [node],
  }
  return item
}
