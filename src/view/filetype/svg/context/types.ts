/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
  LITERAL = bit << 1,
}

export interface ISvgViewPosition {
  readonly x: number
  readonly y: number
}

export interface ISvgViewData {
  readonly mode: ModeEnum
  readonly scale: number
  readonly rotation: number
  readonly position: ISvgViewPosition
}
