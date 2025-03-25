/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { FiletreeMode } from '@/component/filetree/context/types'

const bit: number = 1

export enum MarkdownModeEnum {
  VIEW = bit << 0,
  AST = bit << 1,
  TOC = bit << 2,
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
