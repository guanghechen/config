export enum ModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
}

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath {
  readonly path: string
  readonly expanded?: boolean
}

export interface IJsonlViewRecord {
  readonly lineNumber: number
  readonly data: unknown
  readonly error?: string
}
