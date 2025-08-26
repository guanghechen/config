import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IWhiteboardContentData, IWhiteboardViewData } from './types'

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
}

const DEFAULT_DATA: IWhiteboardViewData = {
  content: null,
  filetype: 'text',
}

const DEFAULT_CONTENT_DATA: IWhiteboardContentData = {
  content: null,
  contentError: null,
  loading: false,
}

export class WhiteboardViewViewModel extends ViewModel {
  public readonly content$: State<string | null>
  public readonly filetype$: State<string>
  public readonly contentData$: State<IWhiteboardContentData>
  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>

  constructor(props: IProps) {
    super()

    const { content = DEFAULT_DATA.content, filetype = DEFAULT_DATA.filetype } = props

    const content$ = new State<string | null>(content)
    const filetype$ = new State<string>(filetype)
    const contentData$ = new State<IWhiteboardContentData>(DEFAULT_CONTENT_DATA)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.content$ = content$
    this.filetype$ = filetype$
    this.contentData$ = contentData$
    this.mainScrollableContainer$ = mainScrollableContainer$
  }

  public static normalize(
    data: Partial<IWhiteboardViewData> | undefined,
    base: IWhiteboardViewData = DEFAULT_DATA,
  ): IWhiteboardViewData {
    const { content, filetype } = data || {}
    const normalizedContent = typeof content === 'string' ? content : base.content
    const normalizedFiletype = typeof filetype === 'string' ? filetype : base.filetype
    const normalizedData: IWhiteboardViewData = {
      content: normalizedContent,
      filetype: normalizedFiletype,
    }
    return normalizedData
  }

  public updateContent = (content: string | null): void => {
    this.content$.next(content)
    this.contentData$.next({
      content,
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

      // Only read text content from clipboard
      const text = await navigator.clipboard.readText()
      this.updateContent(text)
    } catch (error) {
      this.contentData$.next({
        content: null,
        contentError: `Failed to read from clipboard: ${error}`,
        loading: false,
      })
    }
  }

  public selectFile = (): void => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'text/*'
    input.onchange = event => {
      const file = (event.target as HTMLInputElement).files?.[0]
      if (file) {
        this.contentData$.next({ ...this.contentData$.getSnapshot(), loading: true })

        // Only handle text files
        const reader = new FileReader()
        reader.onload = e => {
          const content = e.target?.result as string
          this.updateContent(content)
        }
        reader.onerror = () => {
          this.contentData$.next({
            content: null,
            contentError: 'Failed to read file',
            loading: false,
          })
        }
        reader.readAsText(file)
      }
    }
    input.click()
  }

  public dump = (): IWhiteboardViewData => {
    const content: string | null = this.content$.getSnapshot()
    const filetype: string = this.filetype$.getSnapshot()
    return { content, filetype }
  }

  public load = (data: Partial<IWhiteboardViewData> | undefined): void => {
    const { content, filetype }: IWhiteboardViewData = WhiteboardViewViewModel.normalize(
      data,
      this.dump(),
    )
    this.content$.next(content)
    this.filetype$.next(filetype)
  }
}
