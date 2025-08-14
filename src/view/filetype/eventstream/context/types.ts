import type { IMultiInputItem } from '@/component/MultiInput'

/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  NAVIGATION = bit << 1,
  EXPAND_ALL = bit << 2,
}

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath extends IMultiInputItem {
  readonly path: string
}

export interface IEventStreamViewData {
  readonly mode: ModeEnum
  readonly chainPaths: IChainPath[]
  readonly displayMode: DisplayMode
}
