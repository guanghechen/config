import type { FileTreeModeEnum } from '@/container/filetree/context/types'

export interface IWorkspaceViewData {
  readonly filepath: string | null
  readonly workspaceRoot: string | null
  readonly workspaceRoots: string[]
  readonly workspaceRootsInitialized: boolean

  readonly filetreeKeyword: string
  readonly filetreeMode: FileTreeModeEnum

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}
