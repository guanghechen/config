import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IEventStreamEvent } from '../utils'
import type { DisplayMode, IChainPath, IEventStreamViewData, ModeEnum } from './types'

export interface IEventStreamViewViewModelProps {
  readonly content?: string
  readonly events?: IEventStreamEvent[]
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly expandTick?: number
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const DEFAULT_EVENTSTREAM_VIEW_DATA: IEventStreamViewData = {
  mode: 1,
  chainPaths: [],
  displayMode: 'lines',
}

export class EventStreamViewViewModel extends ViewModel {
  public readonly content$: IState<string>
  public readonly events$: IState<IEventStreamEvent[]>
  public readonly mode$: IState<ModeEnum>
  public readonly activeEventIndex$: IState<number | null>
  public readonly expandTick$: IState<number>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly displayMode$: IState<DisplayMode>

  public static fromData(
    data: Partial<IEventStreamViewData> | undefined,
  ): EventStreamViewViewModel {
    const { mode, chainPaths, displayMode }: IEventStreamViewData = this.normalize(
      DEFAULT_EVENTSTREAM_VIEW_DATA,
      data,
    )
    return new EventStreamViewViewModel({
      mode,
      chainPaths,
      displayMode,
    })
  }

  public static normalize(
    base: IEventStreamViewData,
    data: Partial<IEventStreamViewData> | undefined,
  ): IEventStreamViewData {
    const { mode, chainPaths, displayMode } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedChainPaths: IChainPath[] = Array.isArray(chainPaths)
      ? chainPaths
      : base.chainPaths
    const normalizedDisplayMode: DisplayMode =
      displayMode === 'inline' || displayMode === 'lines' ? displayMode : base.displayMode
    const normalizedData: IEventStreamViewData = {
      mode: normalizedMode,
      chainPaths: normalizedChainPaths,
      displayMode: normalizedDisplayMode,
    }
    return normalizedData
  }

  constructor(props: IEventStreamViewViewModelProps = {}) {
    super()

    const {
      content = '',
      events = [],
      activeEventIndex = null,
      expandTick = 0,
      mode = DEFAULT_EVENTSTREAM_VIEW_DATA.mode,
      chainPaths = DEFAULT_EVENTSTREAM_VIEW_DATA.chainPaths,
      displayMode = DEFAULT_EVENTSTREAM_VIEW_DATA.displayMode,
    } = props

    this.content$ = new State<string>(content)
    this.events$ = new State<IEventStreamEvent[]>(events)
    this.mode$ = new State<ModeEnum>(mode)
    this.activeEventIndex$ = new State<number | null>(activeEventIndex)
    this.expandTick$ = new State<number>(expandTick)
    this.chainPaths$ = new State<IChainPath[]>(chainPaths)
    this.displayMode$ = new State<DisplayMode>(displayMode)
  }

  public dump = (): IEventStreamViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const chainPaths: IChainPath[] = this.chainPaths$.getSnapshot()
    const displayMode: DisplayMode = this.displayMode$.getSnapshot()
    return {
      mode,
      chainPaths,
      displayMode,
    }
  }

  public load = (data: Partial<IEventStreamViewData> | undefined): void => {
    const { mode, chainPaths, displayMode }: IEventStreamViewData =
      EventStreamViewViewModel.normalize(this.dump(), data)
    this.mode$.next(mode)
    this.chainPaths$.next(chainPaths)
    this.displayMode$.next(displayMode)
  }
}
