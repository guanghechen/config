import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { DisplayMode, IChainPath, IJsonlViewData, IJsonlViewRecord, ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const DEFAULT_JSONL_VIEW_DATA: IJsonlViewData = {
  mode: 1,
  chainPaths: [],
  displayMode: 'lines',
}

export class JsonlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly activeRecordIndex$: IState<number | null>
  public readonly expandTick$: IState<number>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly displayMode$: IState<DisplayMode>
  public readonly content$: IState<string | null>
  public readonly jsons$: IState<IJsonlViewRecord[]>
  public readonly error$: IState<string | null>

  public static fromData(data: Partial<IJsonlViewData> | undefined): JsonlViewViewModel {
    const { mode, chainPaths, displayMode }: IJsonlViewData = this.normalize(
      DEFAULT_JSONL_VIEW_DATA,
      data,
    )
    return new JsonlViewViewModel({
      workspace: null,
      filepath: '',
      mode,
      chainPaths,
      displayMode,
    })
  }

  public static normalize(
    base: IJsonlViewData,
    data: Partial<IJsonlViewData> | undefined,
  ): IJsonlViewData {
    const { mode, chainPaths, displayMode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedChainPaths: IChainPath[] = Array.isArray(chainPaths)
      ? chainPaths
      : base.chainPaths
    const normalizedDisplayMode: DisplayMode =
      displayMode === 'inline' || displayMode === 'lines' ? displayMode : base.displayMode
    const normalizedData: IJsonlViewData = {
      mode: normalizedMode,
      chainPaths: normalizedChainPaths,
      displayMode: normalizedDisplayMode,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const {
      workspace,
      filepath,
      activeRecordIndex = 0,
      mode = DEFAULT_JSONL_VIEW_DATA.mode,
      chainPaths = DEFAULT_JSONL_VIEW_DATA.chainPaths,
      displayMode = DEFAULT_JSONL_VIEW_DATA.displayMode,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(mode)
    this.activeRecordIndex$ = new State<number | null>(activeRecordIndex)
    this.expandTick$ = new State<number>(0)
    this.chainPaths$ = new State<IChainPath[]>(chainPaths)
    this.displayMode$ = new State<DisplayMode>(displayMode)
    this.content$ = new State<string | null>(null)
    this.jsons$ = new State<IJsonlViewRecord[]>([])
    this.error$ = new State<string | null>(null)
  }

  public dump = (): IJsonlViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const chainPaths: IChainPath[] = this.chainPaths$.getSnapshot()
    const displayMode: DisplayMode = this.displayMode$.getSnapshot()
    return {
      mode,
      chainPaths,
      displayMode,
    }
  }

  public load = (data: Partial<IJsonlViewData> | undefined): void => {
    const { mode, chainPaths, displayMode }: IJsonlViewData = JsonlViewViewModel.normalize(
      this.dump(),
      data,
    )
    this.mode$.next(mode)
    this.chainPaths$.next(chainPaths)
    this.displayMode$.next(displayMode)
  }
}
