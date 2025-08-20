import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IFileViewData } from './types'

interface IProps {
  readonly filepath?: string | null
}

const DEFAULT_DATA: IFileViewData = {
  filepath: null,
}

export class FileViewViewModel extends ViewModel {
  public readonly filepath$: State<string | null>
  public readonly filepathDirtyTick$: IState<number>
  public readonly mainScrollableContainer$: IState<HTMLDivElement | null>

  constructor(props: IProps) {
    super()

    const { filepath = DEFAULT_DATA.filepath } = props

    const filepath$ = new State<string | null>(filepath)
    const filepathDirtyTick$ = new State<number>(0)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.filepath$ = filepath$
    this.filepathDirtyTick$ = filepathDirtyTick$
    this.mainScrollableContainer$ = mainScrollableContainer$
  }

  public static normalize(
    data: Partial<IFileViewData> | undefined,
    base: IFileViewData = DEFAULT_DATA,
  ): IFileViewData {
    const { filepath } = data || {}
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedData: IFileViewData = {
      filepath: normalizedFilepath,
    }
    return normalizedData
  }

  public markFilepathDirty = (): void => {
    const tick: number = this.filepathDirtyTick$.getSnapshot()
    this.filepathDirtyTick$.next(tick + 1)
  }

  public dump = (): IFileViewData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    return { filepath }
  }

  public load = (data: Partial<IFileViewData> | undefined): void => {
    const { filepath }: IFileViewData = FileViewViewModel.normalize(data, this.dump())
    this.filepath$.next(filepath)
  }
}
