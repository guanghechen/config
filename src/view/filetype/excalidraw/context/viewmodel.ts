import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IJsonFileData } from '@/hook/api/file'
import type { IExcalidrawViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
}

const DEFAULT_DATA: IExcalidrawViewData = {
  mode: ModeEnum.CONTENT,
}

export class ExcalidrawViewViewModel extends ViewModel {
  public readonly filepath$: IState<string>
  public readonly elements$: IState<ReadonlyArray<ExcalidrawElement>>
  public readonly content$: IState<string | null>
  public readonly mode$: IState<ModeEnum>
  public readonly data$: IState<IJsonFileData | null>

  public static fromData(data: Partial<IExcalidrawViewData> | undefined): ExcalidrawViewViewModel {
    const { mode }: IExcalidrawViewData = this.normalize(DEFAULT_DATA, data)
    return new ExcalidrawViewViewModel({
      filepath: '',
      mode,
    })
  }

  public static normalize(
    base: IExcalidrawViewData,
    data: Partial<IExcalidrawViewData> | undefined,
  ): IExcalidrawViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IExcalidrawViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const { filepath, mode = DEFAULT_DATA.mode } = props

    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.elements$ = new State<ReadonlyArray<ExcalidrawElement>>(props.elements ?? [])
    this.content$ = new State<string | null>(props.content ?? null)
    this.data$ = new State<IJsonFileData | null>(null)
  }

  public dump = (): IExcalidrawViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IExcalidrawViewData> | undefined): void => {
    const { mode }: IExcalidrawViewData = ExcalidrawViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
