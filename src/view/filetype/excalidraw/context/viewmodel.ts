import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IJsonFileData } from '@/hook/api/file'
import type { IExcalidrawViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
}

const DEFAULT_DATA: IExcalidrawViewData = {
  mode: ModeEnum.CONTENT,
}

export class ExcalidrawViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly elements$: IState<ReadonlyArray<ExcalidrawElement>>
  public readonly content$: IState<string | null>
  public readonly data$: IState<IJsonFileData | null>

  constructor(props: IProps) {
    super()

    const { workspace, filepath, mode = DEFAULT_DATA.mode, elements = [], content = null } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.elements$ = new State<ReadonlyArray<ExcalidrawElement>>(elements)
    this.content$ = new State<string | null>(content)
    this.data$ = new State<IJsonFileData | null>(null)
  }

  public static normalize(
    data: Partial<IExcalidrawViewData> | undefined,
    base: IExcalidrawViewData = DEFAULT_DATA,
  ): IExcalidrawViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IExcalidrawViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  public dump = (): IExcalidrawViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IExcalidrawViewData> | undefined): void => {
    const base: IExcalidrawViewData = this.dump()
    const { mode }: IExcalidrawViewData = ExcalidrawViewViewModel.normalize(data, base)
    this.mode$.next(mode)
  }
}
