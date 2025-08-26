import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import debounce from 'lodash.debounce'
import type { IWhiteboardContentData, IWhiteboardViewData } from './types'

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
  readonly editorVisible?: boolean
  readonly editorWidth?: number
  readonly editorLanguage?: string
}

const getDefaultEditorWidth = (): number => {
  if (typeof window !== 'undefined') {
    return Math.max(400, window.innerWidth * 0.5)
  }
  return 800
}

const DEFAULT_DATA: IWhiteboardViewData = {
  content: null,
  filetype: 'text',
  editorVisible: false,
  editorWidth: getDefaultEditorWidth(),
  editorLanguage: 'javascript',
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
  public readonly editorVisible$: State<boolean>
  public readonly editorWidth$: State<number>
  public readonly editorLanguage$: State<string>

  public readonly updateEditorWidthDebounced: (nextWidth: number) => void

  constructor(props: IProps) {
    super()

    const {
      content = DEFAULT_DATA.content,
      filetype = DEFAULT_DATA.filetype,
      editorVisible = DEFAULT_DATA.editorVisible,
      editorWidth = DEFAULT_DATA.editorWidth,
      editorLanguage = DEFAULT_DATA.editorLanguage,
    } = props

    const content$ = new State<string | null>(content)
    const filetype$ = new State<string>(filetype)
    const contentData$ = new State<IWhiteboardContentData>(DEFAULT_CONTENT_DATA)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)
    const editorVisible$ = new State<boolean>(editorVisible)
    const editorWidth$ = new State<number>(editorWidth)
    const editorLanguage$ = new State<string>(editorLanguage)

    this.content$ = content$
    this.filetype$ = filetype$
    this.contentData$ = contentData$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.editorVisible$ = editorVisible$
    this.editorWidth$ = editorWidth$
    this.editorLanguage$ = editorLanguage$

    this.updateEditorWidthDebounced = debounce(function (nextWidth: number): void {
      editorWidth$.next(nextWidth)
    }, 100)
  }

  public static normalize(
    data: Partial<IWhiteboardViewData> | undefined,
    base: IWhiteboardViewData = DEFAULT_DATA,
  ): IWhiteboardViewData {
    const { content, filetype, editorVisible, editorWidth, editorLanguage } = data || {}
    const normalizedContent = typeof content === 'string' ? content : base.content
    const normalizedFiletype = typeof filetype === 'string' ? filetype : base.filetype
    const normalizedEditorVisible =
      typeof editorVisible === 'boolean' ? editorVisible : base.editorVisible
    const normalizedEditorWidth = typeof editorWidth === 'number' ? editorWidth : base.editorWidth
    const normalizedEditorLanguage =
      typeof editorLanguage === 'string' ? editorLanguage : base.editorLanguage
    const normalizedData: IWhiteboardViewData = {
      content: normalizedContent,
      filetype: normalizedFiletype,
      editorVisible: normalizedEditorVisible,
      editorWidth: normalizedEditorWidth,
      editorLanguage: normalizedEditorLanguage,
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

  public toggleEditor = (): void => {
    this.editorVisible$.next(!this.editorVisible$.getSnapshot())
  }

  public updateEditorWidth = (width: number): void => {
    this.editorWidth$.next(width)
  }

  public updateEditorLanguage = (language: string): void => {
    this.editorLanguage$.next(language)
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
    const editorVisible: boolean = this.editorVisible$.getSnapshot()
    const editorWidth: number = this.editorWidth$.getSnapshot()
    const editorLanguage: string = this.editorLanguage$.getSnapshot()
    return { content, filetype, editorVisible, editorWidth, editorLanguage }
  }

  public load = (data: Partial<IWhiteboardViewData> | undefined): void => {
    const { content, filetype, editorVisible, editorWidth, editorLanguage }: IWhiteboardViewData =
      WhiteboardViewViewModel.normalize(data, this.dump())
    this.content$.next(content)
    this.filetype$.next(filetype)
    this.editorVisible$.next(editorVisible)
    this.editorWidth$.next(editorWidth)
    this.editorLanguage$.next(editorLanguage)
  }
}
