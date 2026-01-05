import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IFileContentData, IFileViewData } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly filepathHistory?: string[]
}

const MAX_HISTORY_SIZE = 50

const DEFAULT_DATA: IFileViewData = {
  filepath: null,
  filepathHistory: [],
}

const DEFAULT_CONTENT_DATA: IFileContentData = {
  content: null,
  contentError: null,
  url: undefined,
  loading: false,
}

export class FileViewViewModel extends ViewModel {
  public readonly filepath$: State<string | null>
  public readonly filepathHistory$: State<string[]>
  public readonly filepathDirtyTick$: IState<number>
  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>
  public readonly fileContent$: State<IFileContentData>

  constructor(props: IProps) {
    super()

    const { filepath = DEFAULT_DATA.filepath, filepathHistory = DEFAULT_DATA.filepathHistory } =
      props

    const filepath$ = new State<string | null>(filepath)
    const filepathHistory$ = new State<string[]>(filepathHistory)
    const filepathDirtyTick$ = new State<number>(0)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)
    const fileContent$ = new State<IFileContentData>(DEFAULT_CONTENT_DATA)

    this.filepath$ = filepath$
    this.filepathHistory$ = filepathHistory$
    this.filepathDirtyTick$ = filepathDirtyTick$
    this.mainScrollableContainer$ = mainScrollableContainer$
    this.fileContent$ = fileContent$
  }

  public static normalize(
    data: Partial<IFileViewData> | null | undefined,
    base: IFileViewData = DEFAULT_DATA,
  ): IFileViewData {
    const { filepath, filepathHistory } = data || {}
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedFilepathHistory = Array.isArray(filepathHistory)
      ? filepathHistory
      : base.filepathHistory
    const normalizedData: IFileViewData = {
      filepath: normalizedFilepath,
      filepathHistory: normalizedFilepathHistory,
    }
    return normalizedData
  }

  public markFilepathDirty = (): void => {
    const tick: number = this.filepathDirtyTick$.getSnapshot()
    this.filepathDirtyTick$.next(tick + 1)
  }

  public updateFileContent = (contentData: IFileContentData): void => {
    this.fileContent$.next(contentData)
  }

  public addToHistory = (filepath: string): void => {
    const history = this.filepathHistory$.getSnapshot()
    const filtered = history.filter(p => p !== filepath)
    const newHistory = [filepath, ...filtered].slice(0, MAX_HISTORY_SIZE)
    this.filepathHistory$.next(newHistory)
  }

  public dump = (): IFileViewData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    const filepathHistory: string[] = this.filepathHistory$.getSnapshot()
    return { filepath, filepathHistory }
  }

  public load = (data: Partial<IFileViewData> | undefined): void => {
    const { filepath, filepathHistory }: IFileViewData = FileViewViewModel.normalize(
      data,
      this.dump(),
    )
    this.filepath$.next(filepath)
    this.filepathHistory$.next(filepathHistory)
  }
}
