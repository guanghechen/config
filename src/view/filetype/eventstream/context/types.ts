import type { IMultiInputItem } from '@/component/MultiInput'

export enum ModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
  EXPAND_ALL = 4,
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
