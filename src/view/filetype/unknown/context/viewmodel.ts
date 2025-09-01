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

  constructor(props: IProps = {}) {
    super()

    const { mode = DEFAULT_DATA.mode, placeholder = true } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.placeholder$ = new State<boolean>(placeholder)
  }

  public static normalize(
    data: Partial<IUnknownViewData> | null | undefined,
    base: IUnknownViewData = DEFAULT_DATA,
  ): IUnknownViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IUnknownViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  public dump = (): IUnknownViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return { mode }
  }

  public load = (data: Partial<IUnknownViewData> | undefined): void => {
    const base: IUnknownViewData = this.dump()
    const { mode }: IUnknownViewData = UnknownViewViewModel.normalize(data, base)
    this.mode$.next(mode)
  }
}
