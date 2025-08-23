import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IMarkdownFileData } from '@/shared/types/api'
import { type IMarkdownViewData, ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
}

const DEFAULT_DATA: IMarkdownViewData = {
  mode: ModeEnum.CONTENT,
}

export class MarkdownViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>

  public readonly data$: IState<IMarkdownFileData | null>
  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>

  constructor(props: IProps) {
    super()

    const { mode = DEFAULT_DATA.mode } = props

    this.mode$ = new State<ModeEnum>(mode)

    this.data$ = new State<IMarkdownFileData | null>(null)
    this.tocActivatedIdentifier$ = new State<string | null>(null)
    this.specifiedTocActivatedIdentifier$ = new State<string | null>(null)
  }

  public static normalize(
    data: Partial<IMarkdownViewData> | undefined,
    base: IMarkdownViewData = DEFAULT_DATA,
  ): IMarkdownViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IMarkdownViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  public dump = (): IMarkdownViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return { mode }
  }

  public load = (data: Partial<IMarkdownViewData> | undefined): void => {
    const base: IMarkdownViewData = this.dump()
    const { mode }: IMarkdownViewData = MarkdownViewViewModel.normalize(data, base)
    this.mode$.next(mode)
  }
}
