import {
  EventEmitter,
  TreeItem,
  TreeItemCollapsibleState,
  type Disposable,
  type Event,
  type TreeDataProvider,
} from 'vscode'
import type { IComparisonSnapshot } from '../../comparison/model'
import { ComparisonSession } from '../../comparison/session'
import type { IFileChange } from '../../git/file-change'
import { COMMAND_IDS, VIEW_ITEM_CONTEXT_VALUES } from '../../platform/extension-ids'
import { createFileChangeDescription, createFileChangeTooltip } from '../file-change/presentation'
import { createRepositoryResourceUri } from '../file-change/resource'
import { buildFileChangeTree, type IChangeTreeNode } from '../file-change/tree'

export class ComparisonTreeProvider implements TreeDataProvider<IChangeTreeNode>, Disposable {
  private readonly changeEmitter = new EventEmitter<IChangeTreeNode | undefined>()
  private readonly sessionSubscription: Disposable
  private nodes: ReadonlyArray<IChangeTreeNode> = []

  public readonly onDidChangeTreeData: Event<IChangeTreeNode | undefined> = this.changeEmitter.event

  public constructor(private readonly comparisonSession: ComparisonSession) {
    this.sessionSubscription = this.comparisonSession.onDidChange(snapshot => {
      this.nodes = snapshot ? buildFileChangeTree(snapshot.changes) : []
      this.changeEmitter.fire(undefined)
    })
  }

  public getTreeItem(node: IChangeTreeNode): TreeItem {
    if (node.kind === 'directory') {
      const item = new TreeItem(node.name, TreeItemCollapsibleState.Expanded)
      item.id = `directory:${node.path}`
      item.contextValue = VIEW_ITEM_CONTEXT_VALUES.comparisonDirectory
      if (this.comparisonSession.snapshot) {
        item.resourceUri = createRepositoryResourceUri(
          this.comparisonSession.snapshot.repositoryPath,
          node.path,
        )
      }
      item.tooltip = node.path
      return item
    }

    return createFileTreeItem(node, this.comparisonSession.snapshot)
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
  snapshot: IComparisonSnapshot | null,
): TreeItem {
  const item = new TreeItem(node.name, TreeItemCollapsibleState.None)
  item.id = createFileNodeId(node.change)
  item.contextValue = VIEW_ITEM_CONTEXT_VALUES.comparisonFile
  item.description = createFileChangeDescription(node.change)
  item.tooltip = createFileChangeTooltip(node.change)
  if (snapshot) {
    item.resourceUri = createRepositoryResourceUri(
      snapshot.repositoryPath,
      node.path,
      node.change.kind,
    )
    item.command = {
      command: COMMAND_IDS.openComparisonDiff,
      title: 'Open File Diff',
      arguments: [snapshot.revision, node.change],
    }
  }
  return item
}

function createFileNodeId(change: IFileChange): string {
  return `file:${change.status}:${change.previousPath ?? ''}:${change.currentPath ?? ''}`
}
