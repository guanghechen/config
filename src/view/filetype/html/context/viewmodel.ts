import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IHtmlFileData } from '@/hook/api/file'
import type { IHtmlViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly mode?: ModeEnum
}

const DEFAULT_HTML_VIEW_DATA: IHtmlViewData = {
  mode: ModeEnum.VIEW | ModeEnum.TAILWIND,
}

export class HtmlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly mode$: IState<ModeEnum>
  public readonly data$: IState<IHtmlFileData | null>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<IHtmlViewData> | undefined): HtmlViewViewModel {
    const { mode }: IHtmlViewData = this.normalize(DEFAULT_HTML_VIEW_DATA, data)
    return new HtmlViewViewModel({
      workspace: null,
      filepath: null,
      mode,
    })
  }

  public static normalize(
    base: IHtmlViewData,
    data: Partial<IHtmlViewData> | undefined,
  ): IHtmlViewData {
    const { mode } = data || {}
    const normalizedMode: ModeEnum = typeof mode === 'number' ? mode : base.mode
    const normalizedData: IHtmlViewData = {
      mode: normalizedMode,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const { workspace = null, filepath = null, mode = DEFAULT_HTML_VIEW_DATA.mode } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.data$ = new State<IHtmlFileData | null>(null)
    this.error$ = new State<string | null>(null)
  }

  public dump = (): IHtmlViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    return {
      mode,
    }
  }

  public load = (data: Partial<IHtmlViewData> | undefined): void => {
    const { mode }: IHtmlViewData = HtmlViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
  }
}
