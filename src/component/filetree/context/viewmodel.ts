import { State, ViewModel } from '@guanghechen/react-viewmodel'

export type IFileTreeNode = IFileTreeFolderNode | IFileTreeFileNode
export type IFileTreeDataMap = ReadonlyMap<string, IFileTreeNodeData>
export type IFileTreeDataMapMutable = Map<string, IFileTreeNodeDataMutable>

export interface IFileTreePathItem {
  readonly filepath: string
  readonly pathFromRoot: string[]
}

export interface IFileTreeNodeDataMutable {
  basename: string
  depth: number
  filepath: string | undefined
  collapsed: boolean | undefined
}

export type IFileTreeNodeData = Readonly<IFileTreeNodeDataMutable>

export interface IFileTreeRootNode {
  readonly uuid: string
  readonly type: 'root'
  readonly children: IFileTreeNode[]
}

export interface IFileTreeFolderNode {
  readonly uuid: string
  readonly type: 'folder'
  readonly children: IFileTreeNode[]
}

export interface IFileTreeFileNode {
  readonly uuid: string
  readonly type: 'file'
}

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface IProps {
  //
}

export class FileTreeViewModel extends ViewModel {
  public readonly dataMap$: State<ReadonlyMap<string, IFileTreeNodeData>>
  public readonly root$: State<IFileTreeRootNode | null>

  constructor(_props: IProps) {
    super()

    this.dataMap$ = new State<ReadonlyMap<string, IFileTreeNodeData>>(new Map())
    this.root$ = new State<IFileTreeRootNode | null>(null)
  }

  public readonly updateFromFilepaths = (filepaths: string[]): void => {
    const { root, dataMap } = this.buildFileTree(filepaths)
    this.root$.next(root)
    this.dataMap$.next(dataMap)
  }

  public readonly buildFromFilepaths = (filepaths: string[]): void => {
    const { root, dataMap } = this.buildFileTree(filepaths)
    const oldDataMap: IFileTreeDataMap = this.dataMap$.getSnapshot()

    for (const [uuid, item] of dataMap.entries()) {
      const oldItem = oldDataMap.get(uuid)
      if (oldItem) {
        item.collapsed = oldItem.collapsed
      }
    }

    this.root$.next(root)
    this.dataMap$.next(dataMap)
  }

  protected readonly buildFileTree = (
    filepaths: string[],
  ): { root: IFileTreeRootNode; dataMap: IFileTreeDataMapMutable } => {
    const items: IFileTreePathItem[] = []
    for (const filepath of filepaths) {
      const pieces: string[] = filepath.split(/[/\\]+/g)
      const item: IFileTreePathItem = { filepath, pathFromRoot: pieces }
      items.push(item)
    }

    const dataMap: IFileTreeDataMapMutable = new Map()
    const root: IFileTreeRootNode = {
      uuid: '.',
      type: 'root',
      children: buildChildren(0, items.length, 0),
    }
    dataMap.set(root.uuid, {
      basename: '.',
      filepath: '.',
      depth: 0,
      collapsed: false,
    })
    return { root, dataMap }

    function buildChildren(lft: number, rht: number, cur: number): IFileTreeNode[] {
      const nodes: IFileTreeNode[] = []
      for (let i = lft, j: number; i < rht; i = j) {
        const x: string = items[i].pathFromRoot[cur]
        for (j = i + 1; j < rht; ++j) {
          const y: string = items[j].pathFromRoot[cur]
          if (x !== y) break
        }

        const uuid: string = items[i].pathFromRoot.slice(0, cur + 1).join('/')
        if (i + 1 === j) {
          dataMap.set(uuid, {
            basename: items[i].pathFromRoot[cur],
            filepath: items[i].filepath,
            depth: cur + 1,
            collapsed: undefined,
          })
          const node: IFileTreeNode = { uuid, type: 'file' }
          nodes.push(node)
        } else {
          dataMap.set(uuid, {
            basename: items[i].pathFromRoot[cur],
            filepath: undefined,
            depth: cur + 1,
            collapsed: false,
          })
          const node: IFileTreeNode = {
            uuid,
            type: 'folder',
            children: buildChildren(i, j, cur + 1),
          }
          nodes.push(node)
        }
      }
      return nodes
    }
  }
}
