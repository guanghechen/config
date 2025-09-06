export enum ToolMode {
  SELECT = 1,
  LASSO = 2,
  LINE = 4,
  RECTANGLE = 8,
  DIAMOND = 16,
  CIRCLE = 32,
  ARROW = 64,
  FREEDRAW = 128,
  TEXT = 256,
  IMAGE = 512,
  ERASER = 1024,
  FRAME = 2048,
  LASER = 4096,
  PAN = 8192,
}

export interface IHistoryState {
  elements: any[]
  appState?: Partial<IDrawboardAppState>
}

export interface IDrawboardViewData {
  mode: ToolMode
  zoom: number
  offsetX: number
  offsetY: number
  gridSize: number
  showGrid: boolean
  showRulers: boolean
  snapToGrid: boolean
}

export interface IDrawboardAppState {
  selectedElementIds: Record<string, boolean>
  selectedTool: ToolMode
  lastActiveTool: ToolMode | null
  toolLocked: boolean
  viewBackgroundColor: string
  currentItemStrokeColor: string
  currentItemBackgroundColor: string
  currentItemFillStyle: string
  currentItemStrokeWidth: number
  currentItemStrokeStyle: string
  currentItemRoughness: number
  currentItemOpacity: number
  currentItemFont: string
  cursorButton: 'up' | 'down'
  scrolledOutside: boolean
  zoom: {
    value: number
  }
  openMenu: string | null
  lastPointerDownWith: 'mouse' | 'touch' | 'pen'
}
