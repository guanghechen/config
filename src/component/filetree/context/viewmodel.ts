import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Mutable } from '@/shared/types'
import type {
  IFileTreeFileNode,
  IFileTreeFolderNode,
  IFileTreeFolderNodeMutable,
  IFileTreeNode,
  IFileTreeNodeMap,
  IFileTreeNodeMapMutable,
  IFileTreeNodeMutable,
} from './types'
import { FileTreeViewMode } from './types'

interface IFileTreePathItem {
  readonly filepath: string
  readonly pathFromRoot: string[]
}

interface IProps {
  readonly currentFilepath: string | null
}

export class FileTreeViewModel extends ViewModel {
  public readonly nodeMap$: State<ReadonlyMap<string, IFileTreeNode>>
  public readonly root$: State<IFileTreeFolderNode | null>
  public readonly fileNodes$: State<IFileTreeFileNode[]>
  public readonly currentFilepath$: State<string | null>
  public readonly searchKeyword$: State<string>
  public readonly viewMode$: State<FileTreeViewMode>

  constructor(_props: IProps) {
    super()

    this.nodeMap$ = new State<ReadonlyMap<string, IFileTreeNode>>(new Map())
    this.root$ = new State<IFileTreeFolderNode | null>(null)
    this.fileNodes$ = new State<IFileTreeFileNode[]>([])
    this.currentFilepath$ = new State<string | null>(null)
    this.searchKeyword$ = new State<string>('')
    this.viewMode$ = new State<FileTreeViewMode>(FileTreeViewMode.TREE)
  }

  public readonly updateFromFilepaths = (filepaths: string[]): void => {
    const { nodeMap, root, fileNodes } = this.buildFileTree(filepaths)
    this.nodeMap$.next(nodeMap)
    this.root$.next(root)
    this.fileNodes$.next(fileNodes)
  }

  public readonly buildFromFilepaths = (filepaths: string[]): void => {
    const { nodeMap, root, fileNodes } = this.buildFileTree(filepaths)
    const oldNodeMap: IFileTreeNodeMap = this.nodeMap$.getSnapshot()

    for (const [uuid, item] of nodeMap.entries()) {
      const oldNode: IFileTreeNode | undefined = oldNodeMap.get(uuid)
      if (oldNode?.type === 'folder') {
        ;(item as IFileTreeFolderNodeMutable).collapsed = oldNode.collapsed
      }
    }

    this.nodeMap$.next(nodeMap)
    this.root$.next(root)
    this.fileNodes$.next(fileNodes)
  }

  protected readonly buildFileTree = (
    filepaths: string[],
  ): { nodeMap: IFileTreeNodeMap; root: IFileTreeFolderNode; fileNodes: IFileTreeFileNode[] } => {
    const items: IFileTreePathItem[] = []
    for (const filepath of filepaths) {
      const pieces: string[] = filepath.split(/[/\\]+/g)
      const item: IFileTreePathItem = { filepath, pathFromRoot: pieces }
      items.push(item)
    }

    const nodeMap: IFileTreeNodeMapMutable = new Map()
    const root: IFileTreeNodeMutable = {
      uuid: '.',
      type: 'folder',
      parent: null,
      children: [],
      basename: '.',
      depth: 0,
      collapsed: false,
    }
    root.children = buildChildren(0, items.length, 0, root)
    nodeMap.set(root.uuid, root)

    const fileNodes: IFileTreeFileNode[] = []
    collectNodes(root)

    return { nodeMap, root, fileNodes }

    function buildChildren(
      lft: number,
      rht: number,
      cur: number,
      parent: IFileTreeFolderNode,
    ): IFileTreeNode[] {
      const children: IFileTreeNode[] = []
      for (let i = lft, j: number; i < rht; i = j) {
        const item_i: IFileTreePathItem = items[i]
        const x: string = item_i.pathFromRoot[cur]
        for (j = i + 1; j < rht; ++j) {
          const y: string = items[j].pathFromRoot[cur]
          if (x !== y) break
        }

        const uuid: string = item_i.pathFromRoot.slice(0, cur + 1).join('/')
        const basename: string = item_i.pathFromRoot[cur]

        if (i + 1 === j && cur + 1 === item_i.pathFromRoot.length) {
          const dotIndex = basename.lastIndexOf('.')
          const child: IFileTreeFileNode = {
            type: 'file',
            uuid,
            parent,
            basename,
            extname: basename.slice(dotIndex),
            filepath: item_i.filepath,
            filepath_lower: item_i.filepath.toLowerCase(),
            depth: cur + 1,
          }
          nodeMap.set(uuid, child)
          children.push(child)
        } else {
          const child: Mutable<IFileTreeNode> = {
            uuid,
            type: 'folder',
            parent,
            children: [],
            basename,
            depth: cur + 1,
            collapsed: cur > 1,
          }
          child.children = buildChildren(i, j, cur + 1, child)
          nodeMap.set(uuid, child)
          children.push(child)
        }
      }

      children.sort((x, y) => {
        if (x.type !== y.type) return x.type === 'folder' ? -1 : 1
        return x.basename.localeCompare(y.basename)
      })
      return children
    }

    function collectNodes(node: IFileTreeNode): void {
      switch (node.type) {
        case 'file':
          fileNodes.push(node)
          break
        case 'folder':
          for (const child of node.children) collectNodes(child)
          break
      }
    }
  }
}
