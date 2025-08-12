export interface IImageViewPosition {
  readonly x: number
  readonly y: number
}

// Alias for backwards compatibility
export type IImagePosition = IImageViewPosition

export interface IImageViewData {
  readonly scale: number
  readonly rotation: number
  readonly position: IImageViewPosition
}
