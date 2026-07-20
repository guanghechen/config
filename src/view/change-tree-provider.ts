import path from 'node:path'
import {
  EventEmitter,
  TreeItem,
  TreeItemCollapsibleState,
  Uri,
  type Disposable,
  type Event,
  type TreeDataProvider,
} from 'vscode'
import { CompareSession } from '../compare/compare-session'
import type { ICompareSnapshot } from '../compare/model'
import type { IFileChange } from '../git/file-change'
import { buildChangeTree, type IChangeTreeNode } from './change-tree'
import { createFileChangeDescription, createFileChangeTooltip } from './file-change-presentation'

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
      if (this.session.snapshot) {
        item.resourceUri = createRepositoryResourceUri(
          this.session.snapshot.repositoryPath,
          node.path,
        )
      }
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
  item.description = createFileChangeDescription(node.change)
  item.tooltip = createFileChangeTooltip(node.change)
  if (snapshot) {
    item.resourceUri = createRepositoryResourceUri(snapshot.repositoryPath, node.path)
    item.command = {
      command: 'vsgit.openDiff',
      title: 'Open File Diff',
      arguments: [snapshot.revision, node.change],
    }
  }
  return item
}

function createRepositoryResourceUri(repositoryPath: string, relativePath: string): Uri {
  return Uri.file(path.join(repositoryPath, relativePath))
}

function createFileNodeId(change: IFileChange): string {
  return `file:${change.status}:${change.previousPath ?? ''}:${change.currentPath ?? ''}`
}
