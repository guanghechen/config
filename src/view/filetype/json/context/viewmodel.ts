import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IJsonViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
}

const DEFAULT_DATA: IJsonViewData = {
  mode: ModeEnum.CONTENT,
}

export class JsonViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>

  public readonly content$: IState<string | null>
  public readonly json$: IState<unknown>

  constructor(props: IProps) {
    super()

    const { mode = DEFAULT_DATA.mode } = props

    this.mode$ = new State<ModeEnum>(mode)

    this.content$ = new State<string | null>(null)
    this.json$ = new State<unknown>(null)
  }

  public static normalize(
    data: Partial<IJsonViewData> | undefined,
    base: IJsonViewData = DEFAULT_DATA,
  ): IJsonViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const viewData: IJsonViewData = {
      mode: normalizedMode,
    }
    return viewData
  }

  public dump = (): IJsonViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return { mode }
  }

  public load = (data: Partial<IJsonViewData> | undefined): void => {
    const base: IJsonViewData = this.dump()
    const { mode } = JsonViewViewModel.normalize(data, base)
    this.mode$.next(mode)
  }
}
