import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'

export interface IExcalidrawViewData {
  readonly type: string
  readonly version: number
  readonly source: string
  readonly elements: ReadonlyArray<ExcalidrawElement>
  readonly appState: {
    readonly gridSize: number
    readonly viewBackgroundColor: string
  }
}

// Alias for backwards compatibility
export type IExcalidrawData = IExcalidrawViewData
