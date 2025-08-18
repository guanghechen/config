/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { ITextTransformConfig } from '@/shared/types'

const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
  RAW = bit << 1,
  TRANSFORM = bit << 2,
  NAV = bit << 3,
}

export enum ViewModeEnum {
  ORIGINAL = 'original',
  LIST = 'list',
  GRAPH = 'graph',
}

export interface IChainPath {
  readonly path: string
  readonly value: string
  readonly visible: boolean
}

export interface ITextViewData {
  readonly mode: ModeEnum
  readonly viewMode: ViewModeEnum
  readonly transformConfig: ITextTransformConfig
  readonly chainPaths: IChainPath[]
}
