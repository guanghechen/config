import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly tailwindEnabled?: boolean
}

export interface IHtmlViewData {
  readonly tailwindEnabled: boolean
}

const DEFAULT_HTML_VIEW_DATA: IHtmlViewData = {
  tailwindEnabled: false,
}

export class HtmlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly tailwindEnabled$: IState<boolean>

  public static fromData(data: Partial<IHtmlViewData> | undefined): HtmlViewViewModel {
    const { tailwindEnabled }: IHtmlViewData = this.normalize(DEFAULT_HTML_VIEW_DATA, data)
    return new HtmlViewViewModel({
      workspace: null,
      filepath: null,
      tailwindEnabled,
    })
  }

  public static normalize(
    base: IHtmlViewData,
    data: Partial<IHtmlViewData> | undefined,
  ): IHtmlViewData {
    const { tailwindEnabled } = data || {}
    const normalizedTailwindEnabled: boolean =
      typeof tailwindEnabled === 'boolean' ? tailwindEnabled : base.tailwindEnabled
    const normalizedData: IHtmlViewData = {
      tailwindEnabled: normalizedTailwindEnabled,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      workspace = null,
      filepath = null,
      tailwindEnabled = DEFAULT_HTML_VIEW_DATA.tailwindEnabled,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string | null>(filepath)
    this.tailwindEnabled$ = new State<boolean>(tailwindEnabled)
  }

  public dump = (): IHtmlViewData => {
    const tailwindEnabled: boolean = this.tailwindEnabled$.getSnapshot()
    return {
      tailwindEnabled,
    }
  }

  public load = (data: Partial<IHtmlViewData> | undefined): void => {
    const { tailwindEnabled }: IHtmlViewData = HtmlViewViewModel.normalize(this.dump(), data)
    this.tailwindEnabled$.next(tailwindEnabled)
  }

  public toggleTailwind(): void {
    this.tailwindEnabled$.next(!this.tailwindEnabled$.getSnapshot())
  }
}
