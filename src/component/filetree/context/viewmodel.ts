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

interface IFileTreePathItem {
  readonly filepath: string
  readonly pathFromRoot: string[]
}

interface IProps {
  readonly currentFilepath: string | null
}

export class FileTreeViewModel extends ViewModel {
  public readonly nodeMap$: State<ReadonlyMap<string, IFileTreeNode>>
  public readonly nodes$: State<IFileTreeNode[]>
  public readonly currentFilepath$: State<string | null>
  public readonly forceRerenderTick$: State<number> = new State(0)

  constructor(_props: IProps) {
    super()

    this.nodeMap$ = new State<ReadonlyMap<string, IFileTreeNode>>(new Map())
    this.nodes$ = new State<IFileTreeNode[]>([])
    this.currentFilepath$ = new State<string | null>(null)
  }

  public readonly forceRerender = (): void => {
    const tick: number = this.forceRerenderTick$.getSnapshot()
    this.forceRerenderTick$.next(tick + 1)
  }

  public readonly updateFromFilepaths = (filepaths: string[]): void => {
    const { nodeMap, nodes } = this.buildFileTree(filepaths)
    this.nodeMap$.next(nodeMap)
    this.nodes$.next(nodes)
  }

  public readonly buildFromFilepaths = (filepaths: string[]): void => {
    const { nodeMap, nodes } = this.buildFileTree(filepaths)
    const oldNodeMap: IFileTreeNodeMap = this.nodeMap$.getSnapshot()

    for (const [uuid, item] of nodeMap.entries()) {
      const oldNode: IFileTreeNode | undefined = oldNodeMap.get(uuid)
      if (oldNode?.type === 'folder') {
        ;(item as IFileTreeFolderNodeMutable).collapsed = oldNode.collapsed
      }
    }

    this.nodeMap$.next(nodeMap)
    this.nodes$.next(nodes)
  }

  public readonly toggleCollapse = (node: IFileTreeFolderNode): void => {
    // eslint-disable-next-line no-param-reassign
    ;(node as IFileTreeFolderNodeMutable).collapsed = !node.collapsed
    update(node)
    this.forceRerender()

    function update(o: IFileTreeFolderNode): void {
      const nextParentCollapsed: boolean = o.parentCollapsed || o.collapsed
      for (const child of o.children) {
        ;(child as IFileTreeFolderNodeMutable).parentCollapsed = nextParentCollapsed
        if (child.type === 'folder') update(child)
      }
    }
  }

  protected readonly buildFileTree = (
    filepaths: string[],
  ): { nodeMap: IFileTreeNodeMap; nodes: IFileTreeNode[]; root: IFileTreeFolderNode } => {
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
      parentCollapsed: false,
    }
    root.children = buildChildren(0, items.length, 0, root)
    nodeMap.set(root.uuid, root)

    const nodes: IFileTreeNode[] = []
    inorderTraversal(root)
    return { nodeMap, nodes, root }

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
            depth: cur + 1,
            parentCollapsed: parent.parentCollapsed || parent.collapsed,
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
            parentCollapsed: parent.parentCollapsed || parent.collapsed,
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

    function inorderTraversal(root: IFileTreeFolderNode): void {
      nodes.push(root)
      for (const child of root.children) {
        if (child.type === 'folder') inorderTraversal(child)
        else nodes.push(child)
      }
    }
  }
}
