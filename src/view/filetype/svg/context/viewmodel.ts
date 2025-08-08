import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'

export interface ISvgViewPosition {
  readonly x: number
  readonly y: number
}

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
}

export class SvgViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly scale$: IState<number>
  public readonly rotation$: IState<number>
  public readonly position$: IState<ISvgViewPosition>

  constructor(props: IProps) {
    super()

    const { workspace, filepath } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.scale$ = new State<number>(props.scale ?? 1)
    this.rotation$ = new State<number>(props.rotation ?? 0)
    this.position$ = new State<ISvgViewPosition>(props.position ?? { x: 0, y: 0 })
  }
}
