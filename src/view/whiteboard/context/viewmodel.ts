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
  readonly filepath?: string | null
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
  filepath: null,
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
  public readonly filepath$: State<string | null>

  public readonly updateEditorWidthDebounced: (nextWidth: number) => void

  constructor(props: IProps) {
    super()

    const {
      content = DEFAULT_DATA.content,
      filetype = DEFAULT_DATA.filetype,
      editorVisible = DEFAULT_DATA.editorVisible,
      editorWidth = DEFAULT_DATA.editorWidth,
      editorLanguage = DEFAULT_DATA.editorLanguage,
      filepath = DEFAULT_DATA.filepath,
    } = props

    const content$ = new State<string | null>(content)
    const filetype$ = new State<string>(filetype)
    const contentData$ = new State<IWhiteboardContentData>(DEFAULT_CONTENT_DATA)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)
    const editorVisible$ = new State<boolean>(editorVisible)
    const editorWidth$ = new State<number>(editorWidth)
    const editorLanguage$ = new State<string>(editorLanguage)
    const filepath$ = new State<string | null>(filepath)

    this.content$ = content$
    this.filetype$ = filetype$
    this.contentData$ = contentData$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.editorVisible$ = editorVisible$
    this.editorWidth$ = editorWidth$
    this.editorLanguage$ = editorLanguage$
    this.filepath$ = filepath$

    this.updateEditorWidthDebounced = debounce(function (nextWidth: number): void {
      editorWidth$.next(nextWidth)
    }, 100)
  }

  public static normalize(
    data: Partial<IWhiteboardViewData> | undefined,
    base: IWhiteboardViewData = DEFAULT_DATA,
  ): IWhiteboardViewData {
    const { content, filetype, editorVisible, editorWidth, editorLanguage, filepath } = data || {}
    const normalizedContent = typeof content === 'string' ? content : base.content
    const normalizedFiletype = typeof filetype === 'string' ? filetype : base.filetype
    const normalizedEditorVisible =
      typeof editorVisible === 'boolean' ? editorVisible : base.editorVisible
    const normalizedEditorWidth = typeof editorWidth === 'number' ? editorWidth : base.editorWidth
    const normalizedEditorLanguage =
      typeof editorLanguage === 'string' ? editorLanguage : base.editorLanguage
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedData: IWhiteboardViewData = {
      content: normalizedContent,
      filetype: normalizedFiletype,
      editorVisible: normalizedEditorVisible,
      editorWidth: normalizedEditorWidth,
      editorLanguage: normalizedEditorLanguage,
      filepath: normalizedFilepath,
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

  public updateFilepath = (filepath: string | null): void => {
    this.filepath$.next(filepath)
  }

  public saveToFile = async (): Promise<void> => {
    const content = this.content$.getSnapshot()
    if (!content) {
      this.contentData$.next({
        ...this.contentData$.getSnapshot(),
        contentError: 'No content to save',
      })
      return
    }

    try {
      // Generate default filename and MIME type based on filetype
      const filetype = this.filetype$.getSnapshot()
      const extension = this.getFileExtension(filetype)
      const defaultFilename = `whiteboard.${extension}`
      const mimeType = this.getMimeType(filetype)

      // Check if File System Access API is supported
      if ('showSaveFilePicker' in window) {
        // Use the File System Access API for modern browsers
        const fileHandle = await (window as any).showSaveFilePicker({
          suggestedName: defaultFilename,
          types: [
            {
              description: `${filetype} files`,
              accept: {
                [mimeType]: [`.${extension}`],
              },
            },
          ],
        })

        const writable = await fileHandle.createWritable()
        await writable.write(content)
        await writable.close()

        // Update filepath to show the saved filename
        this.updateFilepath(fileHandle.name)
      } else {
        // Fallback to download for browsers that don't support File System Access API
        const element = document.createElement('a')
        const file = new Blob([content], { type: mimeType })
        element.href = URL.createObjectURL(file)
        element.download = defaultFilename
        document.body.appendChild(element)
        element.click()
        document.body.removeChild(element)
        URL.revokeObjectURL(element.href)

        // Update filepath to show the saved filename
        this.updateFilepath(defaultFilename)
      }
    } catch (error) {
      // User cancelled the save dialog or other error occurred
      if ((error as any).name !== 'AbortError') {
        this.contentData$.next({
          ...this.contentData$.getSnapshot(),
          contentError: `Failed to save file: ${error}`,
        })
      }
    }
  }

  private getFileExtension = (filetype: string): string => {
    switch (filetype) {
      case 'markdown':
        return 'md'
      case 'json':
        return 'json'
      case 'html':
        return 'html'
      case 'svg':
        return 'svg'
      case 'excalidraw':
        return 'excalidraw'
      default:
        return 'txt'
    }
  }

  private getMimeType = (filetype: string): string => {
    switch (filetype) {
      case 'markdown':
        return 'text/markdown'
      case 'json':
        return 'application/json'
      case 'html':
        return 'text/html'
      case 'svg':
        return 'image/svg+xml'
      case 'excalidraw':
        return 'application/json'
      default:
        return 'text/plain'
    }
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
    const filepath: string | null = this.filepath$.getSnapshot()
    return { content, filetype, editorVisible, editorWidth, editorLanguage, filepath }
  }

  public load = (data: Partial<IWhiteboardViewData> | undefined): void => {
    const {
      content,
      filetype,
      editorVisible,
      editorWidth,
      editorLanguage,
      filepath,
    }: IWhiteboardViewData = WhiteboardViewViewModel.normalize(data, this.dump())
    this.content$.next(content)
    this.filetype$.next(filetype)
    this.editorVisible$.next(editorVisible)
    this.editorWidth$.next(editorWidth)
    this.editorLanguage$.next(editorLanguage)
    this.filepath$.next(filepath)
  }
}
