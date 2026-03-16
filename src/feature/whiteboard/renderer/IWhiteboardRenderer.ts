import type { ICanvasGraph } from '@/feature/whiteboard/model'

export interface ICanvasPoint {
  readonly x: number
  readonly y: number
}

export interface IPickResult {
  readonly hitType: 'node' | 'edge' | 'port' | 'none'
  readonly hitId?: string
}

export interface IRenderFrame {
  readonly timestamp: number
  readonly invalidatedLayers: ReadonlyArray<'paper' | 'grid' | 'edge' | 'node' | 'overlay' | 'hud'>
  readonly selectedNodeIds: ReadonlyArray<string>
  readonly nodeValidationById: Readonly<Record<string, 'ok' | 'warn' | 'error'>>
  readonly edgeValidationById: Readonly<Record<string, 'ok' | 'warn' | 'error'>>
  readonly selectionBox?: {
    readonly x: number
    readonly y: number
    readonly width: number
    readonly height: number
  }
  readonly draftEdge?: {
    readonly fromPortId: string
    readonly toX: number
    readonly toY: number
    readonly valid: boolean
  }
}

export interface IWhiteboardRenderer {
  attach(canvas: HTMLCanvasElement): void
  resize(width: number, height: number, dpr: number): void
  prepare(scene: ICanvasGraph): void
  render(frame: IRenderFrame): void
  pick(point: ICanvasPoint): IPickResult | null
  dispose(): void
}
