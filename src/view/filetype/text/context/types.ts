/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { ITransformConfig } from '@/shared/transformer'

const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  RAW = bit << 1,
  TRANSFORM = bit << 2,
}

export interface ITextViewData {
  readonly mode: ModeEnum
  readonly transformConfig: ITransformConfig
}
