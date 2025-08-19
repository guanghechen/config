import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IFileData } from './types'

interface IProps {
  readonly filepath: string | null
}

const DEFAULT_DATA: IFileData = {
  filepath: null,
}

export class FileViewModel extends ViewModel {
  public readonly filepath$: State<string | null>
  public readonly filepathDirtyTick$: State<number>
  public readonly mainScrollableContainer$: State<HTMLDivElement | null>

  public static fromData(data: Partial<IFileData> | undefined): FileViewModel {
    const { filepath }: IFileData = this.normalize(DEFAULT_DATA, data)
    return new FileViewModel({ filepath })
  }

  public static normalize(base: IFileData, data: Partial<IFileData> | undefined): IFileData {
    const { filepath } = data || {}
    const normalizedFilepath = typeof filepath === 'string' ? filepath : base.filepath
    const normalizedData: IFileData = {
      filepath: normalizedFilepath,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const { filepath } = props

    const filepath$ = new State<string | null>(filepath)
    const filepathDirtyTick$ = new State<number>(0)
    const mainScrollableContainer$ = new State<HTMLDivElement | null>(null)

    this.filepath$ = filepath$
    this.filepathDirtyTick$ = filepathDirtyTick$
    this.mainScrollableContainer$ = mainScrollableContainer$
  }

  public markFilepathDirty = (): void => {
    const tick: number = this.filepathDirtyTick$.getSnapshot()
    this.filepathDirtyTick$.next(tick + 1)
  }

  public dump = (): IFileData => {
    const filepath: string | null = this.filepath$.getSnapshot()
    return { filepath }
  }

  public load = (data: Partial<IFileData> | undefined): void => {
    const { filepath }: IFileData = FileViewModel.normalize(this.dump(), data)
    this.filepath$.next(filepath)
  }
}
