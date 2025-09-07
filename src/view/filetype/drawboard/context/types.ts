/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { IDrawboardElement } from '@/component/drawboard'

const bit: number = 1

export enum ModeEnum {
  CANVAS = bit << 0,
  SOURCE = bit << 1,
}

export interface IDrawboardViewData {
  readonly mode: ModeEnum
}

export interface IDrawboardData {
  readonly nodes: ReadonlyArray<IDrawboardElement>
  readonly edges: ReadonlyArray<any>
  readonly meta: {
    readonly version: number
    readonly zoom: number
    readonly offsetX: number
    readonly offsetY: number
    readonly gridSize: number
    readonly showGrid: boolean
  }
  readonly title?: string
  readonly description?: string
}
