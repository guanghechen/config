import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IJsonViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly content?: string | null
}

const DEFAULT_JSON_VIEW_DATA: IJsonViewData = {
  mode: ModeEnum.VIEW,
}

export class JsonViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly content$: IState<string | null>

  public static fromData(data: Partial<IJsonViewData> | undefined): JsonViewViewModel {
    const { mode }: IJsonViewData = this.normalize(DEFAULT_JSON_VIEW_DATA, data)
    return new JsonViewViewModel({ mode })
  }

  public static normalize(
    base: IJsonViewData,
    data: Partial<IJsonViewData> | undefined,
  ): IJsonViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IJsonViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()
    this.mode$ = new State<ModeEnum>(props.mode ?? 1)
    this.content$ = new State<string | null>(props.content ?? null)
  }

  public dump = (): IJsonViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IJsonViewData> | undefined): void => {
    const { mode }: IJsonViewData = JsonViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
