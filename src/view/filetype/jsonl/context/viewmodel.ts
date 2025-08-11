import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { DisplayMode, IChainPath, IJsonlViewData, ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly expandedRecords?: Set<number>
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
  public readonly expandedRecords$: IState<Set<number>>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly displayMode$: IState<DisplayMode>

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

    const { workspace, filepath } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.mode$ = new State<ModeEnum>(props.mode ?? 1)
    this.activeRecordIndex$ = new State<number | null>(props.activeRecordIndex ?? null)
    this.expandedRecords$ = new State<Set<number>>(props.expandedRecords ?? new Set())
    this.chainPaths$ = new State<IChainPath[]>(props.chainPaths ?? [])
    this.displayMode$ = new State<DisplayMode>(props.displayMode ?? 'lines')
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
