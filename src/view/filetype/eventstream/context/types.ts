import type { IMultiInputItem } from '@/component/MultiInput'

export enum ModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
}

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath extends IMultiInputItem {
  readonly path: string
}

export interface IEventStreamViewEvent {
  readonly id: string
  readonly data: unknown
  readonly event?: string
  readonly retry?: number
}
