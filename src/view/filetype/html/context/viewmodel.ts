import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IHtmlViewData } from './types'
import { ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
}

const DEFAULT_DATA: IHtmlViewData = {
  mode: ModeEnum.CONTENT | ModeEnum.LITERAL,
  enableTailwindcss: false,
}

export class HtmlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly enableTailwindcss$: IState<boolean>

  public readonly content$: IState<string | null>

  constructor(props: IProps) {
    super()

    const {
      workspace,
      filepath,
      mode = DEFAULT_DATA.mode,
      enableTailwindcss = DEFAULT_DATA.enableTailwindcss,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.enableTailwindcss$ = new State<boolean>(enableTailwindcss)

    this.content$ = new State<string | null>(null)
  }

  public static normalize(
    data: Partial<IHtmlViewData> | undefined,
    base: IHtmlViewData = DEFAULT_DATA,
  ): IHtmlViewData {
    const { mode, enableTailwindcss } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedData: IHtmlViewData = {
      mode: normalizedMode,
      enableTailwindcss: enableTailwindcss ?? base.enableTailwindcss,
    }
    return normalizedData
  }

  public dump = (): IHtmlViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const enableTailwindcss: boolean = this.enableTailwindcss$.getSnapshot()
    return { mode, enableTailwindcss }
  }

  public load = (data: Partial<IHtmlViewData> | undefined): void => {
    const base: IHtmlViewData = this.dump()
    const { mode, enableTailwindcss }: IHtmlViewData = HtmlViewViewModel.normalize(data, base)
    this.mode$.next(mode)
    this.enableTailwindcss$.next(enableTailwindcss)
  }
}
