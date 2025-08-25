import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IWhiteboardContentData, IWhiteboardRichContent, IWhiteboardViewData } from './types'

interface IProps {
  readonly content?: string | null
  readonly richContent?: IWhiteboardRichContent | null
  readonly filetype?: string
}

const DEFAULT_DATA: IWhiteboardViewData = {
  content: null,
  richContent: null,
  filetype: 'text',
}

const DEFAULT_CONTENT_DATA: IWhiteboardContentData = {
  content: null,
  richContent: null,
  contentError: null,
  loading: false,
}

export class WhiteboardViewViewModel extends ViewModel {
  public readonly content$: State<string | null>
  public readonly richContent$: State<IWhiteboardRichContent | null>
  public readonly filetype$: State<string>
  public readonly contentData$: State<IWhiteboardContentData>
  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>

  constructor(props: IProps) {
    super()

    const {
      content = DEFAULT_DATA.content,
      richContent = DEFAULT_DATA.richContent,
      filetype = DEFAULT_DATA.filetype,
    } = props

    const content$ = new State<string | null>(content)
    const richContent$ = new State<IWhiteboardRichContent | null>(richContent)
    const filetype$ = new State<string>(filetype)
    const contentData$ = new State<IWhiteboardContentData>(DEFAULT_CONTENT_DATA)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.content$ = content$
    this.richContent$ = richContent$
    this.filetype$ = filetype$
    this.contentData$ = contentData$
    this.mainScrollableContainer$ = mainScrollableContainer$
  }

  public static normalize(
    data: Partial<IWhiteboardViewData> | undefined,
    base: IWhiteboardViewData = DEFAULT_DATA,
  ): IWhiteboardViewData {
    const { content, richContent, filetype } = data || {}
    const normalizedContent = typeof content === 'string' ? content : base.content
    const normalizedRichContent = richContent || base.richContent
    const normalizedFiletype = typeof filetype === 'string' ? filetype : base.filetype
    const normalizedData: IWhiteboardViewData = {
      content: normalizedContent,
      richContent: normalizedRichContent,
      filetype: normalizedFiletype,
    }
    return normalizedData
  }

  public updateContent = (content: string | null): void => {
    // Clean up previous blob URL if exists
    const currentRichContent = this.richContent$.getSnapshot()
    if (currentRichContent?.type === 'image' && currentRichContent.data.startsWith('blob:')) {
      URL.revokeObjectURL(currentRichContent.data)
    }

    this.content$.next(content)
    this.richContent$.next(null) // Clear rich content when updating text content
    this.contentData$.next({
      content,
      richContent: null,
      contentError: null,
      loading: false,
    })
  }

  public updateRichContent = (richContent: IWhiteboardRichContent | null): void => {
    // Clean up previous blob URL if exists
    const currentRichContent = this.richContent$.getSnapshot()
    if (currentRichContent?.type === 'image' && currentRichContent.data.startsWith('blob:')) {
      URL.revokeObjectURL(currentRichContent.data)
    }

    this.richContent$.next(richContent)
    this.content$.next(null) // Clear text content when updating rich content
    this.contentData$.next({
      content: null,
      richContent,
      contentError: null,
      loading: false,
    })
  }

  public updateFiletype = (filetype: string): void => {
    this.filetype$.next(filetype)
  }

  public updateContentData = (contentData: IWhiteboardContentData): void => {
    this.contentData$.next(contentData)
  }

  public pasteFromClipboard = async (): Promise<void> => {
    try {
      this.contentData$.next({ ...this.contentData$.getSnapshot(), loading: true })

      // Check if clipboard API is available
      if (!navigator.clipboard) {
        throw new Error('Clipboard API not available')
      }

      const clipboardItems = await navigator.clipboard.read()

      for (const clipboardItem of clipboardItems) {
        // Check for image types first
        const imageTypes = clipboardItem.types.filter(type => type.startsWith('image/'))

        if (imageTypes.length > 0) {
          const imageType = imageTypes[0]
          const blob = await clipboardItem.getType(imageType)

          // Create blob URL for the image
          const blobUrl = URL.createObjectURL(blob)

          // Create rich content for the image
          const richContent: IWhiteboardRichContent = {
            type: 'image',
            data: blobUrl,
            metadata: {
              mimeType: imageType,
              size: blob.size,
            },
          }

          // Auto-detect and set filetype to image
          this.updateFiletype('image')
          this.updateRichContent(richContent)
          return
        }
      }

      // Fallback to text if no images found
      const text = await navigator.clipboard.readText()
      this.updateContent(text)
    } catch (error) {
      this.contentData$.next({
        content: null,
        richContent: null,
        contentError: `Failed to read from clipboard: ${error}`,
        loading: false,
      })
    }
  }

  public selectFile = (): void => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = '*/*'
    input.onchange = event => {
      const file = (event.target as HTMLInputElement).files?.[0]
      if (file) {
        this.contentData$.next({ ...this.contentData$.getSnapshot(), loading: true })

        // Check if file is an image
        if (file.type.startsWith('image/')) {
          // Handle image file
          const blobUrl = URL.createObjectURL(file)

          const richContent: IWhiteboardRichContent = {
            type: 'image',
            data: blobUrl,
            metadata: {
              filename: file.name,
              mimeType: file.type,
              size: file.size,
            },
          }

          // Auto-detect and set filetype to image
          this.updateFiletype('image')
          this.updateRichContent(richContent)
        } else {
          // Handle text file
          const reader = new FileReader()
          reader.onload = e => {
            const content = e.target?.result as string
            this.updateContent(content)
          }
          reader.onerror = () => {
            this.contentData$.next({
              content: null,
              richContent: null,
              contentError: 'Failed to read file',
              loading: false,
            })
          }
          reader.readAsText(file)
        }
      }
    }
    input.click()
  }

  public dump = (): IWhiteboardViewData => {
    const content: string | null = this.content$.getSnapshot()
    const richContent: IWhiteboardRichContent | null = this.richContent$.getSnapshot()
    const filetype: string = this.filetype$.getSnapshot()
    return { content, richContent, filetype }
  }

  public load = (data: Partial<IWhiteboardViewData> | undefined): void => {
    // Clean up previous blob URL if exists before loading new data
    const currentRichContent = this.richContent$.getSnapshot()
    if (currentRichContent?.type === 'image' && currentRichContent.data.startsWith('blob:')) {
      URL.revokeObjectURL(currentRichContent.data)
    }

    const { content, richContent, filetype }: IWhiteboardViewData =
      WhiteboardViewViewModel.normalize(data, this.dump())
    this.content$.next(content)
    this.richContent$.next(richContent)
    this.filetype$.next(filetype)
  }

  public cleanup = (): void => {
    // Clean up any blob URLs when the viewmodel is destroyed
    const currentRichContent = this.richContent$.getSnapshot()
    if (currentRichContent?.type === 'image' && currentRichContent.data.startsWith('blob:')) {
      URL.revokeObjectURL(currentRichContent.data)
    }
  }
}
