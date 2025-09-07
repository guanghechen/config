import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IState } from '@guanghechen/react-viewmodel'

export interface IGridConfig {
  readonly size: number
  readonly visible: boolean
  readonly snapToGrid: boolean
  readonly color: string
  readonly opacity: number
}

export const DEFAULT_GRID_CONFIG: IGridConfig = {
  size: 20,
  visible: true,
  snapToGrid: false,
  color: '#e5e5e5',
  opacity: 0.5,
} as const

interface IProps {
  readonly config?: Partial<IGridConfig>
}

export class GridViewModel extends ViewModel {
  public readonly size$: IState<number>
  public readonly visible$: IState<boolean>
  public readonly snapToGrid$: IState<boolean>
  public readonly color$: IState<string>
  public readonly opacity$: IState<number>

  constructor(props: IProps = {}) {
    super()

    const config = { ...DEFAULT_GRID_CONFIG, ...props.config }
    this.size$ = new State<number>(config.size)
    this.visible$ = new State<boolean>(config.visible)
    this.snapToGrid$ = new State<boolean>(config.snapToGrid)
    this.color$ = new State<string>(config.color)
    this.opacity$ = new State<number>(config.opacity)
  }

  public setGridSize = (size: number): void => {
    this.size$.next(size)
  }

  public toggleGridVisibility = (): void => {
    const visible = this.visible$.getSnapshot()
    this.visible$.next(!visible)
  }

  public setGridVisibility = (visible: boolean): void => {
    this.visible$.next(visible)
  }

  public toggleSnapToGrid = (): void => {
    const snapToGrid = this.snapToGrid$.getSnapshot()
    this.snapToGrid$.next(!snapToGrid)
  }

  public setSnapToGrid = (snapToGrid: boolean): void => {
    this.snapToGrid$.next(snapToGrid)
  }

  public setGridColor = (color: string): void => {
    this.color$.next(color)
  }

  public setGridOpacity = (opacity: number): void => {
    const clampedOpacity = Math.max(0, Math.min(1, opacity))
    this.opacity$.next(clampedOpacity)
  }

  public snapToGrid = (x: number, y: number): { x: number; y: number } => {
    const snapToGrid = this.snapToGrid$.getSnapshot()
    const size = this.size$.getSnapshot()

    if (!snapToGrid) {
      return { x, y }
    }

    const snappedX = Math.round(x / size) * size
    const snappedY = Math.round(y / size) * size

    return { x: snappedX, y: snappedY }
  }

  public getGridLines = (
    viewportWidth: number,
    viewportHeight: number,
    offsetX: number,
    offsetY: number,
    zoom: number,
  ): { x: number[]; y: number[] } => {
    const visible = this.visible$.getSnapshot()
    const size = this.size$.getSnapshot()

    if (!visible) {
      return { x: [], y: [] }
    }

    const gridSize = size * zoom
    const startX = -offsetX % gridSize
    const startY = -offsetY % gridSize

    const xLines: number[] = []
    const yLines: number[] = []

    for (let x = startX; x <= viewportWidth; x += gridSize) {
      if (x >= 0) xLines.push(x)
    }

    for (let y = startY; y <= viewportHeight; y += gridSize) {
      if (y >= 0) yLines.push(y)
    }

    return { x: xLines, y: yLines }
  }
}
