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

export interface ISvgViewData {
  readonly scale: number
  readonly rotation: number
  readonly position: ISvgViewPosition
}

const DEFAULT_SVG_VIEW_DATA: ISvgViewData = {
  scale: 1,
  rotation: 0,
  position: { x: 0, y: 0 },
}

export class SvgViewViewModel extends ViewModel {
  public readonly workspace$: IState<string | null>
  public readonly filepath$: IState<string>
  public readonly scale$: IState<number>
  public readonly rotation$: IState<number>
  public readonly position$: IState<ISvgViewPosition>

  public static fromData(data: Partial<ISvgViewData> | undefined): SvgViewViewModel {
    const { scale, rotation, position }: ISvgViewData = this.normalize(DEFAULT_SVG_VIEW_DATA, data)
    return new SvgViewViewModel({
      workspace: null,
      filepath: '',
      scale,
      rotation,
      position,
    })
  }

  public static normalize(
    base: ISvgViewData,
    data: Partial<ISvgViewData> | undefined,
  ): ISvgViewData {
    const { scale, rotation, position } = data || {}
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedRotation: number = typeof rotation === 'number' ? rotation : base.rotation
    const normalizedPosition: ISvgViewPosition =
      position && typeof position.x === 'number' && typeof position.y === 'number'
        ? position
        : base.position
    const normalizedData: ISvgViewData = {
      scale: normalizedScale,
      rotation: normalizedRotation,
      position: normalizedPosition,
    }
    return normalizedData
  }

  constructor(props: IProps) {
    super()

    const {
      workspace,
      filepath,
      scale = DEFAULT_SVG_VIEW_DATA.scale,
      rotation = DEFAULT_SVG_VIEW_DATA.rotation,
      position = DEFAULT_SVG_VIEW_DATA.position,
    } = props

    this.workspace$ = new State<string | null>(workspace)
    this.filepath$ = new State<string>(filepath)
    this.scale$ = new State<number>(scale)
    this.rotation$ = new State<number>(rotation)
    this.position$ = new State<ISvgViewPosition>(position)
  }

  public dump = (): ISvgViewData => {
    const scale: number = this.scale$.getSnapshot()
    const rotation: number = this.rotation$.getSnapshot()
    const position: ISvgViewPosition = this.position$.getSnapshot()
    return {
      scale,
      rotation,
      position,
    }
  }

  public load = (data: Partial<ISvgViewData> | undefined): void => {
    const { scale, rotation, position }: ISvgViewData = SvgViewViewModel.normalize(
      this.dump(),
      data,
    )
    this.scale$.next(scale)
    this.rotation$.next(rotation)
    this.position$.next(position)
  }
}
