import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IHtmlFileData } from '@/hook/api/file'
import type { IHtmlViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
}

const DEFAULT_DATA: IHtmlViewData = {
  mode: ModeEnum.CONTENT | ModeEnum.LITERAL,
  enableTailwindcss: false,
}

export class HtmlViewViewModel extends ViewModel {
  public readonly filepath$: IState<string | null>
  public readonly mode$: IState<ModeEnum>
  public readonly data$: IState<IHtmlFileData | null>
  public readonly contentError$: IState<string | null>
  public readonly enableTailwindcss$: IState<boolean>

  public static fromData(data: Partial<IHtmlViewData> | undefined): HtmlViewViewModel {
    const { mode, enableTailwindcss }: IHtmlViewData = this.normalize(DEFAULT_DATA, data)
    return new HtmlViewViewModel({
      filepath: null,
      mode,
      enableTailwindcss,
    })
  }

  public static normalize(
    base: IHtmlViewData,
    data: Partial<IHtmlViewData> | undefined,
  ): IHtmlViewData {
    const { mode, enableTailwindcss } = data || {}
    const normalizedMode: ModeEnum = typeof mode === 'number' ? mode : base.mode
    const normalizedData: IHtmlViewData = {
      mode: normalizedMode,
      enableTailwindcss: !!enableTailwindcss,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      filepath = null,
      mode = DEFAULT_DATA.mode,
      enableTailwindcss = DEFAULT_DATA.enableTailwindcss,
    } = props

    this.filepath$ = new State<string | null>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.enableTailwindcss$ = new State<boolean>(enableTailwindcss)
    this.data$ = new State<IHtmlFileData | null>(null)
    this.contentError$ = new State<string | null>(null)
  }

  public dump = (): IHtmlViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const enableTailwindcss: boolean = this.enableTailwindcss$.getSnapshot()
    return {
      mode,
      enableTailwindcss,
    }
  }

  public load = (data: Partial<IHtmlViewData> | undefined): void => {
    const { mode, enableTailwindcss }: IHtmlViewData = HtmlViewViewModel.normalize(
      this.dump(),
      data,
    )
    this.mode$.next(mode)
    this.enableTailwindcss$.next(enableTailwindcss)
  }
}
