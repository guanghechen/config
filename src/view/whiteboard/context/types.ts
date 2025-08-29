export interface IWhiteboardViewData {
  readonly content: string | null
  readonly filetype: string
  readonly editorVisible: boolean
  readonly editorWidth: number
  readonly editorLanguage: string
  readonly filepath: string | null
}

export interface IWhiteboardContentData {
  readonly content: string | null
  readonly contentError: string | null
  readonly loading?: boolean
}
