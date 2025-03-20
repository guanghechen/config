import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Mutable } from '@/shared/types'
import type {
  IFileTreeDataMap,
  IFileTreeDataMapMutable,
  IFileTreeFileNode,
  IFileTreeFolderNode,
  IFileTreeNode,
  IFileTreeNodeData,
} from './types'

interface IFileTreePathItem {
  readonly filepath: string
  readonly pathFromRoot: string[]
}

interface IProps {
  readonly currentFilepath: string | null
}

export class FileTreeViewModel extends ViewModel {
  public readonly dataMap$: State<ReadonlyMap<string, IFileTreeNodeData>>
  public readonly nodes$: State<IFileTreeNode[]>
  public readonly currentFilepath$: State<string | null>
  public readonly forceRerenderTick$: State<number> = new State(0)

  constructor(_props: IProps) {
    super()

    this.dataMap$ = new State<ReadonlyMap<string, IFileTreeNodeData>>(new Map())
    this.nodes$ = new State<IFileTreeNode[]>([])
    this.currentFilepath$ = new State<string | null>(null)
  }

  public readonly forceRerender = (): void => {
    const tick: number = this.forceRerenderTick$.getSnapshot()
    this.forceRerenderTick$.next(tick + 1)
  }

  public readonly updateFromFilepaths = (filepaths: string[]): void => {
    const { dataMap, nodes } = this.buildFileTree(filepaths)
    this.dataMap$.next(dataMap)
    this.nodes$.next(nodes)
  }

  public readonly buildFromFilepaths = (filepaths: string[]): void => {
    const { dataMap, nodes } = this.buildFileTree(filepaths)
    const oldDataMap: IFileTreeDataMap = this.dataMap$.getSnapshot()

    for (const [uuid, item] of dataMap.entries()) {
      const oldItem = oldDataMap.get(uuid)
      if (oldItem) {
        item.collapsed = oldItem.collapsed
      }
    }

    this.dataMap$.next(dataMap)
    this.nodes$.next(nodes)
  }

  public readonly checkCollapsed = (node: IFileTreeNode): boolean => {
    const dataMap: IFileTreeDataMap = this.dataMap$.getSnapshot()
    return !!dataMap.get(node.uuid)?.collapsed
  }

  public readonly checkVisible = (node: IFileTreeNode): boolean => {
    const dataMap: IFileTreeDataMap = this.dataMap$.getSnapshot()
    for (let parent = node.parent; parent; parent = parent.parent) {
      if (dataMap.get(parent.uuid)?.collapsed) return false
    }
    return true
  }

  public readonly onToggleCollapse = (uuid: string): void => {
    const data = this.dataMap$.getSnapshot().get(uuid)
    if (data) {
      ;(data as Mutable<IFileTreeNodeData>).collapsed = !data.collapsed
      this.forceRerender()
    }
  }

  protected readonly buildFileTree = (
    filepaths: string[],
  ): { dataMap: IFileTreeDataMapMutable; nodes: IFileTreeNode[]; root: IFileTreeFolderNode } => {
    const items: IFileTreePathItem[] = []
    for (const filepath of filepaths) {
      const pieces: string[] = filepath.split(/[/\\]+/g)
      const item: IFileTreePathItem = { filepath, pathFromRoot: pieces }
      items.push(item)
    }

    const dataMap: IFileTreeDataMapMutable = new Map()
    const root: IFileTreeFolderNode = {
      uuid: '.',
      type: 'folder',
      parent: null,
      children: [],
      basename: '.',
      depth: 0,
    }
    ;(root as Mutable<IFileTreeFolderNode>).children = buildChildren(0, items.length, 0, root)
    dataMap.set(root.uuid, {
      collapsed: false,
    })

    const nodes: IFileTreeNode[] = []
    inorderTraversal(root)
    return { dataMap, nodes, root }

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
          dataMap.set(uuid, {})

          const dotIndex = basename.lastIndexOf('.')
          const node: IFileTreeFileNode = {
            type: 'file',
            uuid,
            parent,
            basename,
            extname: basename.slice(dotIndex),
            filepath: item_i.filepath,
            depth: cur + 1,
          }
          children.push(node)
        } else {
          dataMap.set(uuid, {
            collapsed: cur > 2,
          })
          const child: Mutable<IFileTreeNode> = {
            uuid,
            type: 'folder',
            parent,
            children: [],
            basename,
            depth: cur + 1,
          }
          child.children = buildChildren(i, j, cur + 1, child)
          children.push(child)
        }
      }

      children.sort((x, y) => {
        if (x.type !== y.type) return x.type === 'folder' ? -1 : 1
        return x.basename.localeCompare(y.basename)
      })
      return children
    }

    function inorderTraversal(root: IFileTreeFolderNode): void {
      nodes.push(root)
      for (const child of root.children) {
        if (child.type === 'folder') inorderTraversal(child)
        else nodes.push(child)
      }
    }
  }
}
