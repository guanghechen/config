/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  AST = bit << 1,
  TOC = bit << 2,
  FM = bit << 3,
}

export interface IMarkdownViewData {
  readonly mode: ModeEnum
}
