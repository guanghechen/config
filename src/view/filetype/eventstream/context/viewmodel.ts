import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { DisplayMode, IChainPath, ModeEnum } from './types'

export interface IEventStreamViewViewModelProps {
  readonly content?: string
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly expandedEvents?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

export class EventStreamViewViewModel extends ViewModel {
  public readonly content$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly activeEventIndex$: IState<number | null>
  public readonly expandedEvents$: IState<Set<number>>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly displayMode$: IState<DisplayMode>

  constructor(props: IEventStreamViewViewModelProps = {}) {
    super()
    this.content$ = new State<string>(props.content ?? '')
    this.mode$ = new State<ModeEnum>(props.mode ?? 1)
    this.activeEventIndex$ = new State<number | null>(props.activeEventIndex ?? null)
    this.expandedEvents$ = new State<Set<number>>(props.expandedEvents ?? new Set())
    this.chainPaths$ = new State<IChainPath[]>(props.chainPaths ?? [])
    this.displayMode$ = new State<DisplayMode>(props.displayMode ?? 'lines')
  }
}
