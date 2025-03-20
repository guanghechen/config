import type { Mutable } from '@/shared/types'

export interface IFileTreeFileNode {
  readonly type: 'file'
  readonly uuid: string
  readonly parent: IFileTreeFolderNode | null
  readonly basename: string
  readonly extname: string
  readonly filepath: string
  readonly depth: number
}

export interface IFileTreeFolderNode {
  readonly type: 'folder'
  readonly uuid: string
  readonly parent: IFileTreeFolderNode | null
  readonly children: IFileTreeNode[]
  readonly basename: string
  readonly depth: number
}

export interface IFileTreeFileNodeData {
  readonly collapsed?: boolean
}

export interface IFileTreeFolderNodeData {
  readonly collapsed: boolean
}

export type IFileTreeNode = IFileTreeFolderNode | IFileTreeFileNode
export type IFileTreeNodeData = IFileTreeFolderNodeData | IFileTreeFileNodeData
export type IFileTreeNodeDataMutable = Mutable<IFileTreeNodeData>
export type IFileTreeDataMap = ReadonlyMap<string, IFileTreeNodeData>
export type IFileTreeDataMapMutable = Map<string, IFileTreeNodeDataMutable>
