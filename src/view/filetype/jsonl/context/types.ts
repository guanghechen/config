export enum ModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
  EXPAND_ALL = 4,
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
