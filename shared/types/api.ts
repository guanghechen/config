import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'

export enum ServerCustomEventType {
  FILE_CHANGED = 'guanghechen/file-changed',
  FILE_SWITCHED = 'guanghechen/file-switch',
}

export interface IResponsePayloadFileChanged {
  readonly workspace: string | null
  readonly filepath: string
}

export interface IResponsePayloadFileSwitch {
  readonly workspace: string | null
  readonly filepath: string
}

export interface IResponsePayloadWorkspaces {
  readonly workspaces: Array<{ readonly tag: string }>
}

// File data interfaces
export interface IMarkdownFileData {
  readonly ast: Root
  readonly toc: IHeadingToc
  readonly frontmatter: Record<string, unknown>
}

export interface IJsonFileData {
  readonly content: string
}

export interface IEventStreamFileData {
  readonly content: string
}

export interface IJsonlFileData {
  readonly content: string
}

export interface IPdfFileData {
  readonly url: string
}

export interface ISvgFileData {
  readonly content: string
}

export interface IHtmlFileData {
  readonly content: string
}

export interface ITextFileData {
  readonly content: string
}

export interface IImageFileData {
  readonly url: string
  readonly width?: number
  readonly height?: number
  readonly size?: number
  readonly format?: string
}

export type IFetchFileData =
  | IMarkdownFileData
  | IJsonFileData
  | IEventStreamFileData
  | IJsonlFileData
  | IPdfFileData
  | ISvgFileData
  | IHtmlFileData
  | ITextFileData
  | IImageFileData

export interface IFetchFileResult<T extends IFetchFileData = IFetchFileData> {
  readonly loading?: boolean
  readonly data?: T | undefined
  readonly text?: string | undefined
  readonly url?: string | undefined
  readonly error?: string | undefined
}
