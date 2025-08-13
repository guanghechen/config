import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IMarkdownFileData } from '@/util/fetch'
import { type IMarkdownViewData, ModeEnum } from './types'

export interface IMarkdownViewViewModelProps {
  readonly workspace?: string | null
  readonly filepath?: string
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
}

const DEFAULT_VIEWMODEL_DATA: IMarkdownViewData = {
  mode: ModeEnum.VIEW,
}

export class MarkdownViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>
  public readonly mode$: IState<ModeEnum>
  public readonly data$: IState<IMarkdownFileData | null>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<IMarkdownViewData> | undefined): MarkdownViewViewModel {
    const { mode }: IMarkdownViewData = this.normalize(DEFAULT_VIEWMODEL_DATA, data)
    return new MarkdownViewViewModel({ mode })
  }

  public static normalize(
    base: IMarkdownViewData,
    data: Partial<IMarkdownViewData> | undefined,
  ): IMarkdownViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IMarkdownViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IMarkdownViewViewModelProps = {}) {
    super()
    this.workspace$ = new State<string | null>(props.workspace ?? null)
    this.filepath$ = new State<string>(props.filepath ?? '')
    this.tocActivatedIdentifier$ = new State<string | null>(props.tocActivatedIdentifier ?? null)
    this.specifiedTocActivatedIdentifier$ = new State<string | null>(
      props.specifiedTocActivatedIdentifier ?? null,
    )
    this.mode$ = new State<ModeEnum>(props.mode ?? ModeEnum.VIEW)
    this.data$ = new State<IMarkdownFileData | null>(null)
    this.error$ = new State<string | null>(null)
  }

  public dump = (): IMarkdownViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IMarkdownViewData> | undefined): void => {
    const { mode }: IMarkdownViewData = MarkdownViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
