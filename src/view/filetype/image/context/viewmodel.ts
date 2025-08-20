import type { IState } from '@guanghechen/react-viewmodel'
import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IImageViewData, IImageViewPosition } from './types'

interface IProps {
  readonly filepath?: string | null
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
}

const DEFAULT_DATA: IImageViewData = {
  scale: 1,
  rotation: 0,
  position: { x: 0, y: 0 },
}

export class ImageViewViewModel extends ViewModel {
  public readonly filepath$: IState<string | null>
  public readonly scale$: IState<number>
  public readonly rotation$: IState<number>
  public readonly position$: IState<IImageViewPosition>

  public static fromData(data: Partial<IImageViewData> | undefined): ImageViewViewModel {
    const { scale, rotation, position }: IImageViewData = this.normalize(DEFAULT_DATA, data)
    return new ImageViewViewModel({
      filepath: null,
      scale,
      rotation,
      position,
    })
  }

  public static normalize(
    base: IImageViewData,
    data: Partial<IImageViewData> | undefined,
  ): IImageViewData {
    const { scale, rotation, position } = data || {}
    const normalizedScale: number = typeof scale === 'number' && scale > 0 ? scale : base.scale
    const normalizedRotation: number = typeof rotation === 'number' ? rotation : base.rotation
    const normalizedPosition: IImageViewPosition =
      position && typeof position.x === 'number' && typeof position.y === 'number'
        ? position
        : base.position
    const normalizedData: IImageViewData = {
      scale: normalizedScale,
      rotation: normalizedRotation,
      position: normalizedPosition,
    }
    return normalizedData
  }

  constructor(props: IProps = {}) {
    super()

    const {
      filepath = null,
      scale = DEFAULT_DATA.scale,
      rotation = DEFAULT_DATA.rotation,
      position = DEFAULT_DATA.position,
    } = props

    this.filepath$ = new State<string | null>(filepath)
    this.scale$ = new State<number>(scale)
    this.rotation$ = new State<number>(rotation)
    this.position$ = new State<IImageViewPosition>(position)
  }

  public dump = (): IImageViewData => {
    const scale: number = this.scale$.getSnapshot()
    const rotation: number = this.rotation$.getSnapshot()
    const position: IImageViewPosition = this.position$.getSnapshot()
    return {
      scale,
      rotation,
      position,
    }
  }

  public load = (data: Partial<IImageViewData> | undefined): void => {
    const { scale, rotation, position }: IImageViewData = ImageViewViewModel.normalize(
      this.dump(),
      data,
    )
    this.scale$.next(scale)
    this.rotation$.next(rotation)
    this.position$.next(position)
  }
}
