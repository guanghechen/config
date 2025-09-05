export enum ToolMode {
  SELECT = 1,
  LINE = 2,
  RECTANGLE = 4,
  CIRCLE = 8,
  ARROW = 16,
  PAN = 32,
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
