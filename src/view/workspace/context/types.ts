import type { FileTreeModeEnum } from '@/component/filetree/context/types'

export interface IWorkspaceItem {
  readonly tag: string
}

export interface IWorkspaceData {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly filetreeKeyword: string
  readonly filetreeMode: FileTreeModeEnum

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}
