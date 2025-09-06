import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { DrawboardElement } from '@/component/drawboard'
import type { IDrawboardViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly saveFile?: (content: string) => void
}

const DEFAULT_DATA: IDrawboardViewData = {
  mode: ModeEnum.CANVAS,
}

export class DrawboardViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly elements$: IState<ReadonlyArray<DrawboardElement>>
  public readonly content$: IState<string | null>
  public readonly saveFile?: (content: string) => void

  constructor(props: IProps) {
    super()

    const { mode = DEFAULT_DATA.mode, saveFile: onSaveFile } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.elements$ = new State<ReadonlyArray<DrawboardElement>>([])
    this.content$ = new State<string | null>(null)
    this.saveFile = onSaveFile
  }

  public static normalize(
    data: Partial<IDrawboardViewData> | undefined,
    base: IDrawboardViewData = DEFAULT_DATA,
  ): IDrawboardViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IDrawboardViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  public dump = (): IDrawboardViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IDrawboardViewData> | undefined): void => {
    const base: IDrawboardViewData = this.dump()
    const { mode }: IDrawboardViewData = DrawboardViewViewModel.normalize(data, base)
    this.mode$.next(mode)
  }
}
