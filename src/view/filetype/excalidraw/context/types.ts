/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'

const bit: number = 1

export enum ModeEnum {
  CONTENT = bit << 0,
}

export interface IExcalidrawViewData {
  readonly mode: ModeEnum
}

export interface IExcalidrawData {
  readonly type: string
  readonly version: number
  readonly source: string
  readonly elements: ReadonlyArray<ExcalidrawElement>
  readonly appState: {
    readonly gridSize: number
    readonly viewBackgroundColor: string
  }
}
