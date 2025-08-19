import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IMarkdownFileData } from '@/hook/api/file'
import { type IMarkdownViewData, ModeEnum } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
}

const DEFAULT_DATA: IMarkdownViewData = {
  mode: ModeEnum.CONTENT,
}

export class MarkdownViewViewModel extends ViewModel {
  public readonly filepath$: IState<string | null>
  public readonly tocActivatedIdentifier$: IState<string | null>
  public readonly specifiedTocActivatedIdentifier$: IState<string | null>
  public readonly mode$: IState<ModeEnum>
  public readonly data$: IState<IMarkdownFileData | null>
  public readonly contentError$: IState<string | null>

  public static fromData(data: Partial<IMarkdownViewData> | undefined): MarkdownViewViewModel {
    const { mode }: IMarkdownViewData = this.normalize(DEFAULT_DATA, data)
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

  constructor(props: IProps = {}) {
    super()
    this.filepath$ = new State<string | null>(props.filepath ?? null)
    this.tocActivatedIdentifier$ = new State<string | null>(props.tocActivatedIdentifier ?? null)
    this.specifiedTocActivatedIdentifier$ = new State<string | null>(
      props.specifiedTocActivatedIdentifier ?? null,
    )
    this.mode$ = new State<ModeEnum>(props.mode ?? ModeEnum.CONTENT)
    this.data$ = new State<IMarkdownFileData | null>(null)
    this.contentError$ = new State<string | null>(null)
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
