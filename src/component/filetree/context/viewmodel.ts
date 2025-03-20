import { State, ViewModel } from '@guanghechen/react-viewmodel'
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

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface IProps {
  //
}

export class FileTreeViewModel extends ViewModel {
  public readonly dataMap$: State<ReadonlyMap<string, IFileTreeNodeData>>
  public readonly root$: State<IFileTreeFolderNode | null>

  constructor(_props: IProps) {
    super()

    this.dataMap$ = new State<ReadonlyMap<string, IFileTreeNodeData>>(new Map())
    this.root$ = new State<IFileTreeFolderNode | null>(null)
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
  ): { root: IFileTreeFolderNode; dataMap: IFileTreeDataMapMutable } => {
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
      children: buildChildren(0, items.length, 0),
      basename: '.',
      depth: 0,
    }
    dataMap.set(root.uuid, {
      collapsed: false,
    })
    return { root, dataMap }

    function buildChildren(lft: number, rht: number, cur: number): IFileTreeNode[] {
      const nodes: IFileTreeNode[] = []
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
            basename,
            extname: basename.slice(dotIndex),
            filepath: item_i.filepath,
            depth: cur + 1,
          }
          nodes.push(node)
        } else {
          dataMap.set(uuid, {
            collapsed: false,
          })
          const node: IFileTreeNode = {
            uuid,
            type: 'folder',
            children: buildChildren(i, j, cur + 1),
            basename,
            depth: cur + 1,
          }
          nodes.push(node)
        }
      }

      nodes.sort((x, y) => {
        if (x.type !== y.type) return x.type === 'folder' ? -1 : 1
        return x.basename.localeCompare(y.basename)
      })
      return nodes
    }
  }
}
