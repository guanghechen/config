/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  NAVIGATION = bit << 1,
  EXPAND_ALL = bit << 2,
}

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath {
  readonly path: string
  readonly value: string
  readonly visible: boolean
}

export interface IJsonlRecord {
  readonly index: number
  readonly content: string
  readonly parsed?: unknown
  readonly isValid: boolean
}

export interface IJsonlViewRecord extends IJsonlRecord {}

export interface IJsonlViewData {
  readonly mode: ModeEnum
  readonly chainPaths: IChainPath[]
  readonly displayMode: DisplayMode
}
