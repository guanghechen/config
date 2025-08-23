import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IUnknownViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly placeholder?: boolean
}

const DEFAULT_DATA: IUnknownViewData = {
  mode: ModeEnum.VIEW,
}

export class UnknownViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly placeholder$: IState<boolean>

  public static fromData(data: Partial<IUnknownViewData> | undefined): UnknownViewViewModel {
    const { mode }: IUnknownViewData = this.normalize(DEFAULT_DATA, data)
    return new UnknownViewViewModel({ mode })
  }

  public static normalize(
    base: IUnknownViewData,
    data: Partial<IUnknownViewData> | undefined,
  ): IUnknownViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IUnknownViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const { mode = DEFAULT_DATA.mode, placeholder = true } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.placeholder$ = new State<boolean>(placeholder)
  }

  public dump = (): IUnknownViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return { mode }
  }

  public load = (data: Partial<IUnknownViewData> | undefined): void => {
    const { mode }: IUnknownViewData = UnknownViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
