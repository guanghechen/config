import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import debounce from 'lodash.debounce'
import { toast } from 'react-toastify'
import { FileSystemAccessStorage, generateDefaultFilename } from '../../../util/file-system-access'
import type { IFileHandle, IWhiteboardContentData, IWhiteboardViewData } from './types'

// Optimized constant map for whiteboard filetype to editor language mapping
const WHITEBOARD_FILETYPE_TO_EDITOR_LANGUAGE: Record<string, string> = {
  markdown: 'markdown',
  json: 'json',
  html: 'html',
  svg: 'xml',
  excalidraw: 'json',
  text: 'plaintext',
} as const

// Optimized function for suggesting editor language based on whiteboard filetype
const suggestEditorLanguageForFiletype = (whiteboardFiletype: string): string => {
  return WHITEBOARD_FILETYPE_TO_EDITOR_LANGUAGE[whiteboardFiletype] ?? 'plaintext'
}

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
  readonly editorVisible?: boolean
  readonly editorWidth?: number
  readonly editorLanguage?: string
  readonly filename?: string | null
  readonly fsHandle?: IFileHandle | null
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
  filename: null,
  fsHandle: null,
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
  public readonly filename$: State<string | null>
  public readonly fsHandle$: State<IFileHandle | null>

  public readonly updateEditorWidthDebounced: (nextWidth: number) => void
  private static readonly STORAGE_KEY = 'whiteboard-file-handle'

  constructor(props: IProps) {
    super()

    const {
      content = DEFAULT_DATA.content,
      filetype = DEFAULT_DATA.filetype,
      editorVisible = DEFAULT_DATA.editorVisible,
      editorWidth = DEFAULT_DATA.editorWidth,
      editorLanguage = DEFAULT_DATA.editorLanguage,
      filename = DEFAULT_DATA.filename,
      fsHandle = DEFAULT_DATA.fsHandle,
    } = props

    const content$ = new State<string | null>(content)
    const filetype$ = new State<string>(filetype)
    const contentData$ = new State<IWhiteboardContentData>(DEFAULT_CONTENT_DATA)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)
    const editorVisible$ = new State<boolean>(editorVisible)
    const editorWidth$ = new State<number>(editorWidth)
    const editorLanguage$ = new State<string>(editorLanguage)
    const filename$ = new State<string | null>(filename)
    const fsHandle$ = new State<IFileHandle | null>(fsHandle)

    this.content$ = content$
    this.filetype$ = filetype$
    this.contentData$ = contentData$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.editorVisible$ = editorVisible$
    this.editorWidth$ = editorWidth$
    this.editorLanguage$ = editorLanguage$
    this.filename$ = filename$
    this.fsHandle$ = fsHandle$

    this.updateEditorWidthDebounced = debounce(function (nextWidth: number): void {
      editorWidth$.next(nextWidth)
    }, 100)
  }

  public static normalize(
    data: Partial<IWhiteboardViewData> | null | undefined,
    base: IWhiteboardViewData = DEFAULT_DATA,
  ): IWhiteboardViewData {
    const { content, filetype, editorVisible, editorWidth, editorLanguage, filename, fsHandle } =
      data || {}
    const normalizedContent = typeof content === 'string' ? content : base.content
    const normalizedFiletype = typeof filetype === 'string' ? filetype : base.filetype
    const normalizedEditorVisible =
      typeof editorVisible === 'boolean' ? editorVisible : base.editorVisible
    const normalizedEditorWidth = typeof editorWidth === 'number' ? editorWidth : base.editorWidth
    const normalizedEditorLanguage =
      typeof editorLanguage === 'string' ? editorLanguage : base.editorLanguage
    const normalizedFilename = typeof filename === 'string' ? filename : base.filename
    const normalizedFsHandle = fsHandle || base.fsHandle
    const normalizedData: IWhiteboardViewData = {
      content: normalizedContent,
      filetype: normalizedFiletype,
      editorVisible: normalizedEditorVisible,
      editorWidth: normalizedEditorWidth,
      editorLanguage: normalizedEditorLanguage,
      filename: normalizedFilename,
      fsHandle: normalizedFsHandle,
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
    // Auto-suggest editor language when whiteboard filetype changes
    const suggestedEditorLanguage = suggestEditorLanguageForFiletype(filetype)
    if (suggestedEditorLanguage !== this.editorLanguage$.getSnapshot()) {
      this.editorLanguage$.next(suggestedEditorLanguage)
    }
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

  public updateFilename = (filename: string | null): void => {
    this.filename$.next(filename)
  }

  public updateFsHandle = (fsHandle: IFileHandle | null): void => {
    this.fsHandle$.next(fsHandle)
    if (fsHandle?.handle && fsHandle?.filename) {
      void FileSystemAccessStorage.storeFileHandle(
        WhiteboardViewViewModel.STORAGE_KEY,
        fsHandle.handle,
        fsHandle.filename,
      )
    } else {
      void FileSystemAccessStorage.removeFileHandle(WhiteboardViewViewModel.STORAGE_KEY)
    }
  }

  public saveToFile = async (): Promise<void> => {
    const content = this.content$.getSnapshot()
    if (!content) {
      this.contentData$.next({
        ...this.contentData$.getSnapshot(),
        contentError: 'No content to save',
      })
      toast.error('No content to save')
      return
    }

    try {
      const filetype = this.filetype$.getSnapshot()
      const extension = this.getFileExtension(filetype)
      const mimeType = this.getMimeType(filetype)
      const currentFsHandle = this.fsHandle$.getSnapshot()

      if (FileSystemAccessStorage.isSupported()) {
        // Use the File System Access API
        const fileHandle = await FileSystemAccessStorage.saveFile(content, {
          suggestedName: currentFsHandle?.filename || generateDefaultFilename(extension),
          existingHandle: currentFsHandle?.handle || undefined,
          types: [
            {
              description: `${filetype} files`,
              accept: {
                [mimeType]: [`.${extension}`],
              },
            },
          ],
        })

        // Update filename and file handle
        this.updateFilename(fileHandle.name)
        this.updateFsHandle({ handle: fileHandle, filename: fileHandle.name })
        toast.success('File saved successfully!')
      } else {
        // Fallback to download for browsers that don't support File System Access API
        const defaultFilename = currentFsHandle?.filename || generateDefaultFilename(extension)
        const element = document.createElement('a')
        const file = new Blob([content], { type: mimeType })
        element.href = URL.createObjectURL(file)
        element.download = defaultFilename
        document.body.appendChild(element)
        element.click()
        document.body.removeChild(element)
        URL.revokeObjectURL(element.href)

        // Update filename only for fallback download
        this.updateFilename(defaultFilename)
        toast.success('File downloaded successfully!')
      }
    } catch (error) {
      // User cancelled the save dialog or other error occurred
      if ((error as any).name !== 'AbortError') {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
        this.contentData$.next({
          ...this.contentData$.getSnapshot(),
          contentError: `Failed to save file: ${errorMessage}`,
        })
        toast.error(`Failed to save file: ${errorMessage}`)
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

  private detectFiletypeFromExtension = (extension: string): string => {
    switch (extension.toLowerCase()) {
      case 'md':
      case 'markdown':
        return 'markdown'
      case 'json':
        return 'json'
      case 'html':
      case 'htm':
        return 'html'
      case 'svg':
        return 'svg'
      case 'excalidraw':
        return 'excalidraw'
      case 'txt':
      default:
        return 'text'
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

  public selectFile = async (): Promise<void> => {
    try {
      this.contentData$.next({ ...this.contentData$.getSnapshot(), loading: true })

      if (FileSystemAccessStorage.isSupported()) {
        // Use File System Access API
        const fileHandles = await FileSystemAccessStorage.selectFile({
          multiple: false,
          types: [
            {
              description: 'Text files',
              accept: {
                'text/*': ['.txt', '.md', '.json', '.html', '.svg', '.excalidraw'],
              },
            },
          ],
        })

        if (fileHandles.length > 0) {
          const fileHandle = fileHandles[0]
          const content = await FileSystemAccessStorage.readFile(fileHandle)

          // Update content and file handle
          this.updateContent(content)
          this.updateFilename(fileHandle.name)
          this.updateFsHandle({ handle: fileHandle, filename: fileHandle.name })

          // Auto-detect filetype based on file extension
          const extension = fileHandle.name.split('.').pop()?.toLowerCase()
          if (extension) {
            const detectedFiletype = this.detectFiletypeFromExtension(extension)
            this.updateFiletype(detectedFiletype) // This will also auto-suggest editor filetype
          }
        }
      } else {
        // Fallback to traditional file input
        const input = document.createElement('input')
        input.type = 'file'
        input.accept = 'text/*'
        input.onchange = event => {
          const file = (event.target as HTMLInputElement).files?.[0]
          if (file) {
            const reader = new FileReader()
            reader.onload = e => {
              const content = e.target?.result as string
              this.updateContent(content)
              this.updateFilename(file.name)
              this.updateFsHandle(null) // No handle for traditional file input

              // Auto-detect filetype
              const extension = file.name.split('.').pop()?.toLowerCase()
              if (extension) {
                const detectedFiletype = this.detectFiletypeFromExtension(extension)
                this.updateFiletype(detectedFiletype) // This will also auto-suggest editor filetype
              }
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
    } catch (error) {
      if ((error as any).name !== 'AbortError') {
        this.contentData$.next({
          content: null,
          contentError: `Failed to select file: ${error}`,
          loading: false,
        })
      } else {
        // User cancelled, just reset loading state
        this.contentData$.next({
          ...this.contentData$.getSnapshot(),
          loading: false,
        })
      }
    }
  }

  public dump = (): IWhiteboardViewData => {
    const content: string | null = this.content$.getSnapshot()
    const filetype: string = this.filetype$.getSnapshot()
    const editorVisible: boolean = this.editorVisible$.getSnapshot()
    const editorWidth: number = this.editorWidth$.getSnapshot()
    const editorLanguage: string = this.editorLanguage$.getSnapshot()
    const filename: string | null = this.filename$.getSnapshot()
    const fsHandle: IFileHandle | null = this.fsHandle$.getSnapshot()
    return {
      content,
      filetype,
      editorVisible,
      editorWidth,
      editorLanguage,
      filename,
      fsHandle,
    }
  }

  public load = (data: Partial<IWhiteboardViewData> | undefined): void => {
    const {
      content,
      filetype,
      editorVisible,
      editorWidth,
      editorLanguage,
      filename,
      fsHandle,
    }: IWhiteboardViewData = WhiteboardViewViewModel.normalize(data, this.dump())
    this.content$.next(content)
    this.filetype$.next(filetype)
    this.editorVisible$.next(editorVisible)
    this.editorWidth$.next(editorWidth)
    this.editorLanguage$.next(editorLanguage)
    this.filename$.next(filename)
    this.fsHandle$.next(fsHandle)
  }

  public loadStoredFileHandle = async (): Promise<void> => {
    try {
      const storedHandle = await FileSystemAccessStorage.getFileHandle(
        WhiteboardViewViewModel.STORAGE_KEY,
      )
      this.fsHandle$.next(storedHandle)
      this.filename$.next(storedHandle?.filename ?? null)
    } catch (error) {
      console.warn('Failed to load stored file handle:', error)
    }
  }
}
