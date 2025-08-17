/* eslint-disable @typescript-eslint/prefer-literal-enum-member */

const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  RAW = bit << 1,
}

export interface IUnknownViewData {
  readonly mode: ModeEnum
}
