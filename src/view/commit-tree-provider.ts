import {
  Disposable,
  EventEmitter,
  ThemeIcon,
  TreeItem,
  TreeItemCollapsibleState,
  type Event,
  type TreeDataProvider,
} from 'vscode'
import { GitClient } from '../git/git-client'
import { CommitHistorySession } from '../history/commit-history-session'
import { CommitMarkSession } from '../history/commit-mark-session'
import {
  buildCommitChangeTree,
  createCommitRootNodes,
  type ICommitFileNode,
  type ICommitNode,
  type ICommitTreeNode,
} from './commit-tree'
import { createFileChangeDescription, createFileChangeTooltip } from './file-change-presentation'
import { createRepositoryResourceUri } from './file-change-resource'
import { formatCommitSubject } from './commit-subject'

export class CommitTreeProvider implements TreeDataProvider<ICommitTreeNode>, Disposable {
  private readonly changeEmitter = new EventEmitter<ICommitTreeNode | undefined>()
  private readonly childCache = new Map<string, Promise<ICommitTreeNode[]>>()
  private readonly subscriptions: Disposable

  public readonly onDidChangeTreeData: Event<ICommitTreeNode | undefined> = this.changeEmitter.event

  public constructor(
    private readonly gitClient: GitClient,
    private readonly marks: CommitMarkSession,
    private readonly session: CommitHistorySession,
  ) {
    this.subscriptions = Disposable.from(
      this.session.onDidChange(() => {
        this.childCache.clear()
        this.changeEmitter.fire(undefined)
      }),
      this.marks.onDidChange(() => this.changeEmitter.fire(undefined)),
    )
  }

  public getTreeItem(node: ICommitTreeNode): TreeItem {
    switch (node.kind) {
      case 'commit':
        return createCommitTreeItem(
          node,
          this.marks.isMarked(node.context.repositoryPath, node.context.commit.hash),
        )
      case 'commit-directory': {
        const item = new TreeItem(node.name, TreeItemCollapsibleState.Expanded)
        item.id = `commit-directory:${node.context.commit.hash}:${node.path}`
        item.contextValue = 'vsgit.commitDirectory'
        item.resourceUri = createRepositoryResourceUri(node.context.repositoryPath, node.path)
        item.tooltip = node.path
        return item
      }
      case 'commit-file':
        return createCommitFileTreeItem(node)
      case 'commit-error': {
        const item = new TreeItem('Unable to load commit changes', TreeItemCollapsibleState.None)
        item.id = `commit-error:${node.commitHash}`
        item.contextValue = 'vsgit.commitError'
        item.description = node.message
        item.iconPath = new ThemeIcon('error')
        item.tooltip = node.message
        return item
      }
      case 'load-more-commits': {
        const item = new TreeItem('Load more commits…', TreeItemCollapsibleState.None)
        item.id = `load-more-commits:${node.historyRevision}`
        item.contextValue = 'vsgit.loadMoreCommits'
        item.iconPath = new ThemeIcon('unfold')
        item.command = { command: 'vsgit.loadMoreCommits', title: 'Load More Commits' }
        return item
      }
    }
  }

  public getChildren(node?: ICommitTreeNode): ICommitTreeNode[] | Promise<ICommitTreeNode[]> {
    if (!node) {
      const snapshot = this.session.snapshot
      return snapshot ? [...createCommitRootNodes(snapshot)] : []
    }
    if (node.kind === 'commit') return this.getCommitChildren(node)
    if (node.kind === 'commit-directory') return [...node.children]
    return []
  }

  public dispose(): void {
    this.childCache.clear()
    this.subscriptions.dispose()
    this.changeEmitter.dispose()
  }

  private getCommitChildren(node: ICommitNode): Promise<ICommitTreeNode[]> {
    const cacheKey = `${node.context.historyRevision}:${node.context.commit.hash}`
    const existing = this.childCache.get(cacheKey)
    if (existing) return existing

    const request = this.loadCommitChildren(node, cacheKey)
    this.childCache.set(cacheKey, request)
    return request
  }

  private async loadCommitChildren(
    node: ICommitNode,
    cacheKey: string,
  ): Promise<ICommitTreeNode[]> {
    try {
      const changes = await this.gitClient.listCommitChanges(
        node.context.repositoryPath,
        node.context.commit.hash,
        node.context.parentCommit,
      )
      if (this.session.snapshot?.revision !== node.context.historyRevision) return []
      return [...buildCommitChangeTree(node.context, changes)]
    } catch (cause) {
      this.childCache.delete(cacheKey)
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
  const item = new TreeItem(
    formatCommitSubject(commit.subject) || '(no commit message)',
    TreeItemCollapsibleState.Collapsed,
  )
  item.id = `commit:${commit.hash}`
  item.contextValue = marked ? 'vsgit.commitMarked' : 'vsgit.commit'
  item.description = `${marked ? 'Marked · ' : ''}${commit.shortHash} · ${commit.authorName || 'Unknown author'}`
  item.iconPath = new ThemeIcon(marked ? 'bookmark' : 'git-commit')
  item.tooltip = [
    commit.subject || '(no commit message)',
    '',
    ...(marked ? ['Marked for comparison', ''] : []),
    commit.hash,
    `Author: ${commit.authorName || 'Unknown author'}`,
    `Date: ${new Date(commit.authoredAt).toLocaleString()}`,
  ].join('\n')
  return item
}

function createCommitFileTreeItem(node: ICommitFileNode): TreeItem {
  const item = new TreeItem(node.name, TreeItemCollapsibleState.None)
  item.id = `commit-file:${node.context.commit.hash}:${node.change.status}:${node.path}`
  item.contextValue = 'vsgit.commitFile'
  item.description = createFileChangeDescription(node.change)
  item.resourceUri = createRepositoryResourceUri(
    node.context.repositoryPath,
    node.path,
    node.change.kind,
  )
  item.tooltip = createFileChangeTooltip(node.change)
  item.command = {
    command: 'vsgit.openCommitFileDiff',
    title: 'Open Commit File Diff',
    arguments: [node],
  }
  return item
}
