/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
  LITERAL = bit << 1,
}

export interface IJsonViewData {
  readonly mode: ModeEnum
}
