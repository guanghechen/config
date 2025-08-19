/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
}

export interface IExcalidrawViewData {
  readonly mode: ModeEnum
}
