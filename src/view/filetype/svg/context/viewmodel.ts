import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import { type ISvgViewData, type ISvgViewPosition, ModeEnum } from './types'

interface IProps {
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
}

const DEFAULT_DATA: ISvgViewData = {
  mode: ModeEnum.CONTENT | ModeEnum.LITERAL,
  scale: 1,
  rotation: 0,
  position: { x: 0, y: 0 },
}

export class SvgViewViewModel extends ViewModel {
  public readonly mode$: IState<ModeEnum>
  public readonly scale$: IState<number>
  public readonly rotation$: IState<number>
  public readonly position$: IState<ISvgViewPosition>

  public readonly content$: IState<string | null>

  constructor(props: IProps) {
    super()

    const {
      mode = DEFAULT_DATA.mode,
      scale = DEFAULT_DATA.scale,
      rotation = DEFAULT_DATA.rotation,
      position = DEFAULT_DATA.position,
    } = props

    this.mode$ = new State<ModeEnum>(mode)
    this.scale$ = new State<number>(scale)
    this.rotation$ = new State<number>(rotation)
    this.position$ = new State<ISvgViewPosition>(position)

    this.content$ = new State<string | null>(null)
  }

  public static normalize(
    data: Partial<ISvgViewData> | undefined,
    base: ISvgViewData = DEFAULT_DATA,
  ): ISvgViewData {
    const { mode, scale, rotation, position } = data || {}
    const normalizedMode: ModeEnum =
      typeof mode === 'number' && mode > 0 && Number.isInteger(mode) ? mode : base.mode
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedRotation: number = typeof rotation === 'number' ? rotation : base.rotation
    const normalizedPosition: ISvgViewPosition =
      position && typeof position.x === 'number' && typeof position.y === 'number'
        ? position
        : base.position
    const normalizedData: ISvgViewData = {
      mode: normalizedMode,
      scale: normalizedScale,
      rotation: normalizedRotation,
      position: normalizedPosition,
    }
    return normalizedData
  }

  public dump = (): ISvgViewData => {
    const mode: ModeEnum = this.mode$.getSnapshot()
    const scale: number = this.scale$.getSnapshot()
    const rotation: number = this.rotation$.getSnapshot()
    const position: ISvgViewPosition = this.position$.getSnapshot()
    return { mode, scale, rotation, position }
  }

  public load = (data: Partial<ISvgViewData> | undefined): void => {
    const base: ISvgViewData = this.dump()
    const { mode, scale, rotation, position }: ISvgViewData = SvgViewViewModel.normalize(data, base)
    this.mode$.next(mode)
    this.scale$.next(scale)
    this.rotation$.next(rotation)
    this.position$.next(position)
  }
}
