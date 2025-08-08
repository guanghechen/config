import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { DisplayMode, IChainPath, ModeEnum } from './types'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly expandedRecords?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

export class JsonlViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly mode$: IState<ModeEnum>
  public readonly activeRecordIndex$: IState<number | null>
  public readonly expandedRecords$: IState<Set<number>>
  public readonly chainPaths$: IState<IChainPath[]>
  public readonly displayMode$: IState<DisplayMode>

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
}
