import type { FiletreeMode } from '@/component/filetree/context/types'

export enum MarkdownModeEnum {
  AST = 'ast',
  PREVIEW = 'preview',
  SBS = 'sbs',
}

export interface IWorkspaceItem {
  readonly tag: string
}

export interface IWorkspaceData {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly filetreeKeyword: string
  readonly filetreeMode: FiletreeMode
  readonly markdownMode: MarkdownModeEnum

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
}
