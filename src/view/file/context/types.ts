export interface IFileViewData {
  readonly filepath: string | null
}

export interface IFileContentData {
  readonly content: string | null
  readonly contentError: string | null
  readonly url?: string
  readonly loading?: boolean
}
