export interface IFileHandle {
  readonly handle: FileSystemFileHandle | null
  readonly filename: string | null
}

export interface IWhiteboardViewData {
  readonly content: string | null
  readonly filetype: string
  readonly editorVisible: boolean
  readonly editorWidth: number
  readonly editorLanguage: string
  readonly filename: string | null
  readonly fsHandle: IFileHandle | null
}

export interface IWhiteboardContentData {
  readonly content: string | null
  readonly contentError: string | null
  readonly loading?: boolean
}
