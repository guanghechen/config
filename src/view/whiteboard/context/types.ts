export interface IWhiteboardRichContent {
  readonly type: 'text' | 'image'
  readonly data: string // For text: content string, For image: data URL or blob URL
  readonly metadata?: {
    readonly filename?: string
    readonly mimeType?: string
    readonly size?: number
    readonly width?: number
    readonly height?: number
  }
}

export interface IWhiteboardViewData {
  readonly content: string | null
  readonly richContent?: IWhiteboardRichContent | null
  readonly filetype: string
}

export interface IWhiteboardContentData {
  readonly content: string | null
  readonly richContent?: IWhiteboardRichContent | null
  readonly contentError: string | null
  readonly loading?: boolean
}
