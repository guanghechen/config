import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IExcalidrawViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly saveFile?: (content: string) => void
}

const DEFAULT_DATA: IExcalidrawViewData = {
  mode: ModeEnum.CONTENT,
}

export class ExcalidrawViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly elements$: IState<ReadonlyArray<ExcalidrawElement>>
  public readonly content$: IState<string | null>
  public readonly saveFile?: (content: string) => void

  constructor(props: IProps) {
    super()

    const { mode = DEFAULT_DATA.mode, saveFile: onSaveFile } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.elements$ = new State<ReadonlyArray<ExcalidrawElement>>([])
    this.content$ = new State<string | null>(null)
    this.saveFile = onSaveFile
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
