import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IImageViewPosition } from './types'

export interface IImageViewViewModelProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
}

export class ImageViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string | null>
  public readonly scale$: IState<number>
  public readonly rotation$: IState<number>
  public readonly position$: IState<IImageViewPosition>

  constructor(props: IImageViewViewModelProps = {}) {
    super()
    this.workspace$ = new State<string | null>(props.workspace ?? null)
    this.filepath$ = new State<string | null>(props.filepath ?? null)
    this.scale$ = new State<number>(props.scale ?? 1)
    this.rotation$ = new State<number>(props.rotation ?? 0)
    this.position$ = new State<IImageViewPosition>(props.position ?? { x: 0, y: 0 })
  }
}
