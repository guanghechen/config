/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { FileTreeModeEnum } from '@/component/filetree/context/types'
import { ModeEnum as MarkdownModeEnum } from '@/view/filetype/markdown/context/types'

export { MarkdownModeEnum }

const bit: number = 1

export enum JsonModeEnum {
  LITERAL = bit << 0,
  VIEW = bit << 1,
}

export interface IWorkspaceItem {
  readonly tag: string
}

export interface IWorkspaceData {
  readonly filepath: string | null
  readonly workspace: string | null
  readonly workspaces: IWorkspaceItem[]

  readonly filetreeKeyword: string
  readonly filetreeMode: FileTreeModeEnum
  readonly jsonMode: JsonModeEnum
  readonly markdownMode: MarkdownModeEnum

  readonly sidebarVisible: boolean
  readonly sidebarWidth: number
  readonly topbarVisible: boolean
}
