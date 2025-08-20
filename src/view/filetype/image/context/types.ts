/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
  LITERAL = bit << 1,
}

export interface IImageViewPosition {
  readonly x: number
  readonly y: number
}

export interface IImageViewData {
  readonly mode: ModeEnum
  readonly scale: number
  readonly rotation: number
  readonly position: IImageViewPosition
}

export interface IImageFileData {
  readonly url: string
  readonly width?: number
  readonly height?: number
  readonly size?: number
  readonly format?: string
}
