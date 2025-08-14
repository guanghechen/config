import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { ITextViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly workspace?: string | null
  readonly filepath?: string | null
}

const DEFAULT_TEXT_VIEW_DATA: ITextViewData = {
  mode: ModeEnum.VIEW,
}

export class TextViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly content$: IState<string | null>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<ITextViewData> | undefined): TextViewViewModel {
    const { mode }: ITextViewData = this.normalize(DEFAULT_TEXT_VIEW_DATA, data)
    return new TextViewViewModel({ mode })
  }

  public static normalize(
    base: ITextViewData,
    data: Partial<ITextViewData> | undefined,
  ): ITextViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: ITextViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const { mode = ModeEnum.VIEW, workspace = null, filepath = null } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.content$ = new State<string | null>(null)
    this.error$ = new State<string | null>(null)
  }

  public dump = (): ITextViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<ITextViewData> | undefined): void => {
    const { mode }: ITextViewData = TextViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
