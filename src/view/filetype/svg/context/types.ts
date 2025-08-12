export interface ISvgViewPosition {
  readonly x: number
  readonly y: number
}

export interface ISvgViewData {
  readonly scale: number
  readonly rotation: number
  readonly position: ISvgViewPosition
}
