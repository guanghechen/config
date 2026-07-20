import {
  EventEmitter,
  MarkdownString,
  ThemeIcon,
  TreeItem,
  TreeItemCollapsibleState,
  type Disposable,
  type Event,
  type TreeDataProvider,
} from 'vscode'
import { CompareSession } from '../compare/compare-session'
import type { ICompareSnapshot } from '../compare/model'
import type { FileChangeKind, IFileChange } from '../git/file-change'
import { buildChangeTree, type IChangeTreeNode } from './change-tree'

export class ChangeTreeProvider implements TreeDataProvider<IChangeTreeNode>, Disposable {
  private readonly changeEmitter = new EventEmitter<IChangeTreeNode | undefined>()
  private readonly sessionSubscription: Disposable
  private nodes: ReadonlyArray<IChangeTreeNode> = []

  public readonly onDidChangeTreeData: Event<IChangeTreeNode | undefined> = this.changeEmitter.event

  public constructor(private readonly session: CompareSession) {
    this.sessionSubscription = this.session.onDidChange(snapshot => {
      this.nodes = snapshot ? buildChangeTree(snapshot.changes) : []
      this.changeEmitter.fire(undefined)
    })
  }

  public getTreeItem(node: IChangeTreeNode): TreeItem {
    if (node.kind === 'directory') {
      const item = new TreeItem(node.name, TreeItemCollapsibleState.Collapsed)
      item.id = `directory:${node.path}`
      item.contextValue = 'vsgit.directory'
      item.iconPath = ThemeIcon.Folder
      item.tooltip = node.path
      return item
    }

    return createFileTreeItem(node, this.session.snapshot)
  }

  public getChildren(node?: IChangeTreeNode): IChangeTreeNode[] {
    if (!node) return [...this.nodes]
    return node.kind === 'directory' ? [...node.children] : []
  }

  public dispose(): void {
    this.sessionSubscription.dispose()
    this.changeEmitter.dispose()
  }
}

function createFileTreeItem(
  node: IChangeTreeNode & { readonly kind: 'file' },
  snapshot: ICompareSnapshot | null,
): TreeItem {
  const item = new TreeItem(node.name, TreeItemCollapsibleState.None)
  item.id = createFileNodeId(node.change)
  item.contextValue = 'vsgit.file'
  item.description = createDescription(node.change)
  item.iconPath = new ThemeIcon(resolveIcon(node.change.kind))
  item.tooltip = createTooltip(node.change)
  if (snapshot) {
    item.command = {
      command: 'vsgit.openDiff',
      title: 'Open File Diff',
      arguments: [snapshot.revision, node.change],
    }
  }
  return item
}

function createFileNodeId(change: IFileChange): string {
  return `file:${change.status}:${change.previousPath ?? ''}:${change.currentPath ?? ''}`
}

function createDescription(change: IFileChange): string {
  if (change.kind === 'renamed' || change.kind === 'copied') {
    return `${change.status} · ${change.previousPath ?? ''}`
  }
  return change.status
}

function createTooltip(change: IFileChange): MarkdownString {
  const tooltip = new MarkdownString(undefined, false)
  tooltip.appendText(`${change.status} `)
  if (change.previousPath && change.currentPath && change.previousPath !== change.currentPath) {
    tooltip.appendText(`${change.previousPath} → ${change.currentPath}`)
  } else {
    tooltip.appendText(change.currentPath ?? change.previousPath ?? '')
  }
  return tooltip
}

function resolveIcon(kind: FileChangeKind): string {
  switch (kind) {
    case 'added':
      return 'diff-added'
    case 'deleted':
      return 'diff-removed'
    case 'renamed':
    case 'copied':
      return 'diff-renamed'
    case 'modified':
    case 'typeChanged':
    case 'unmerged':
    case 'unknown':
      return 'diff-modified'
  }
}
