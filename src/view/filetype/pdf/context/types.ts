/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
}

export interface IPdfViewData {
  readonly mode: ModeEnum
  readonly scale: number
  readonly multiview: boolean
  readonly pageNo: number
  readonly pageTotal: number
}
