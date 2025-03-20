import type { Mutable } from '@/shared/types'

export interface IFileTreeFileNode {
  readonly type: 'file'
  readonly uuid: string
  readonly parent: IFileTreeFolderNode | null
  readonly basename: string
  readonly extname: string
  readonly filepath: string
  readonly depth: number
  readonly parentCollapsed: boolean
}

export interface IFileTreeFolderNode {
  readonly type: 'folder'
  readonly uuid: string
  readonly parent: IFileTreeFolderNode | null
  readonly children: IFileTreeNode[]
  readonly basename: string
  readonly depth: number
  readonly collapsed: boolean
  readonly parentCollapsed: boolean
}

export type IFileTreeFileNodeMutable = Mutable<IFileTreeFileNode>
export type IFileTreeFolderNodeMutable = Mutable<IFileTreeFolderNode>

export type IFileTreeNode = IFileTreeFolderNode | IFileTreeFileNode
export type IFileTreeNodeMutable = IFileTreeFileNodeMutable | IFileTreeFolderNodeMutable

export type IFileTreeNodeMap = ReadonlyMap<string, IFileTreeNode>
export type IFileTreeNodeMapMutable = Map<string, IFileTreeNodeMutable>
