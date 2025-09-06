import { State, ViewModel } from '@guanghechen/viewmodel'
import type { IState } from '@guanghechen/viewmodel'
import type { DrawboardElement } from '../types/elements'
import type { IDrawboardAppState, IDrawboardViewData, IHistoryState } from './types'
import { ToolMode } from './types'

interface IProps {
  mode?: ToolMode
  onSave?: (elements: DrawboardElement[]) => void
}

const DEFAULT_VIEW_DATA: IDrawboardViewData = {
  mode: ToolMode.SELECT,
  zoom: 1,
  offsetX: 0,
  offsetY: 0,
  gridSize: 20,
  showGrid: true,
  showRulers: false,
  snapToGrid: false,
}

const DEFAULT_APP_STATE: Partial<IDrawboardAppState> = {
  selectedElementIds: {},
  selectedTool: ToolMode.SELECT,
  lastActiveTool: null,
  toolLocked: false,
  viewBackgroundColor: '#ffffff',
  currentItemStrokeColor: '#000000',
  currentItemBackgroundColor: 'transparent',
  currentItemFillStyle: 'solid',
  currentItemStrokeWidth: 2,
  currentItemStrokeStyle: 'solid',
  currentItemRoughness: 1,
  currentItemOpacity: 100,
  currentItemFont: 'Virgil, Segoe UI Emoji',
  cursorButton: 'up',
  scrolledOutside: false,
  zoom: { value: 1 },
  openMenu: null,
  lastPointerDownWith: 'mouse',
}

export class DrawboardViewModel extends ViewModel {
  // Observable states
  public readonly mode$: IState<ToolMode>
  public readonly elements$: IState<DrawboardElement[]>
  public readonly appState$: IState<IDrawboardAppState>
  public readonly viewData$: IState<IDrawboardViewData>

  // History management
  private history: IHistoryState[] = []
  private historyIndex = -1
  private readonly maxHistorySize = 50

  // Callbacks
  public readonly onSave?: (elements: DrawboardElement[]) => void

  constructor(props: IProps) {
    super()

    const { mode = DEFAULT_VIEW_DATA.mode, onSave } = props

    this.mode$ = new State<ToolMode>(mode)
    this.elements$ = new State<DrawboardElement[]>([])
    this.appState$ = new State<IDrawboardAppState>(DEFAULT_APP_STATE as IDrawboardAppState)
    this.viewData$ = new State<IDrawboardViewData>(DEFAULT_VIEW_DATA)
    this.onSave = onSave

    // Initialize history with current state
    this.pushToHistory()
  }

  // History management
  private pushToHistory = (): void => {
    const currentState: IHistoryState = {
      elements: structuredClone(this.elements$.getSnapshot()),
      appState: structuredClone(this.appState$.getSnapshot()),
    }

    // Remove future history when pushing new state
    this.history = this.history.slice(0, this.historyIndex + 1)
    this.history.push(currentState)

    // Limit history size
    if (this.history.length > this.maxHistorySize) {
      this.history = this.history.slice(-this.maxHistorySize)
      this.historyIndex = this.maxHistorySize - 1
    } else {
      this.historyIndex = this.history.length - 1
    }
  }

  private restoreFromHistory = (state: IHistoryState): void => {
    this.elements$.next(structuredClone(state.elements))
    if (state.appState) {
      this.appState$.next({ ...this.appState$.getSnapshot(), ...state.appState })
    }
  }

  public undo = (): void => {
    if (this.historyIndex > 0) {
      this.historyIndex--
      this.restoreFromHistory(this.history[this.historyIndex])
    }
  }

  public redo = (): void => {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++
      this.restoreFromHistory(this.history[this.historyIndex])
    }
  }

  public canUndo = (): boolean => this.historyIndex > 0

  public canRedo = (): boolean => this.historyIndex < this.history.length - 1

  public clearCanvas = (): void => {
    this.elements$.next([])
    this.pushToHistory()
  }

  // Element management
  public addElement = (element: DrawboardElement): void => {
    const elements = [...this.elements$.getSnapshot(), element]
    this.elements$.next(elements)
    this.pushToHistory()
  }

  public updateElement = (id: string, updates: Record<string, any>): void => {
    const elements = this.elements$.getSnapshot().map(el => {
      if (el.id === id) {
        const updated: DrawboardElement = { ...el, ...updates, updated: Date.now() }
        return updated
      }
      return el
    })
    this.elements$.next(elements)
    this.pushToHistory()
  }

  public deleteElements = (ids: string[]): void => {
    const idSet = new Set(ids)
    const elements = this.elements$.getSnapshot().filter(el => !idSet.has(el.id))
    this.elements$.next(elements)
    this.pushToHistory()
  }

  // View management
  public setZoom = (zoom: number): void => {
    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({ ...viewData, zoom })

    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, zoom: { value: zoom } })
  }

  public pan = (deltaX: number, deltaY: number): void => {
    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({
      ...viewData,
      offsetX: viewData.offsetX + deltaX,
      offsetY: viewData.offsetY + deltaY,
    })
  }

  public setTool = (tool: ToolMode): void => {
    const appState = this.appState$.getSnapshot()

    // Store last active tool (excluding selection tools)
    const lastActiveTool = [ToolMode.SELECT, ToolMode.LASSO, ToolMode.PAN].includes(
      appState.selectedTool,
    )
      ? appState.lastActiveTool
      : appState.selectedTool

    this.mode$.next(tool)
    this.appState$.next({
      ...appState,
      selectedTool: tool,
      lastActiveTool,
    })
  }

  public toggleToolLock = (): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, toolLocked: !appState.toolLocked })
  }

  public switchToLastActiveTool = (): void => {
    const appState = this.appState$.getSnapshot()
    if (appState.lastActiveTool) {
      this.setTool(appState.lastActiveTool)
    }
  }

  public toggleGrid = (): void => {
    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({ ...viewData, showGrid: !viewData.showGrid })
  }

  public toggleRulers = (): void => {
    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({ ...viewData, showRulers: !viewData.showRulers })
  }

  // Properties management
  public setStrokeColor = (color: string): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemStrokeColor: color })
  }

  public setFillColor = (color: string): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemBackgroundColor: color })
  }

  public setBackgroundColor = (color: string): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, viewBackgroundColor: color })
  }

  public setStrokeWidth = (width: number): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemStrokeWidth: width })
  }

  public setRoughness = (roughness: number): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemRoughness: roughness })
  }

  public setOpacity = (opacity: number): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemOpacity: opacity })
  }

  public setGridSize = (size: number): void => {
    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({ ...viewData, gridSize: size })
  }

  // Selection management
  public getSelectedElements = (): DrawboardElement[] => {
    const appState = this.appState$.getSnapshot()
    const elements = this.elements$.getSnapshot()
    return elements.filter(el => appState.selectedElementIds[el.id])
  }

  public selectElements = (ids: string[]): void => {
    const selectedElementIds: Record<string, boolean> = {}
    ids.forEach(id => {
      selectedElementIds[id] = true
    })

    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, selectedElementIds })
  }

  public clearSelection = (): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, selectedElementIds: {} })
  }

  public deleteSelectedElements = (): void => {
    const selectedElements = this.getSelectedElements()
    if (selectedElements.length > 0) {
      this.deleteElements(selectedElements.map(el => el.id))
      this.clearSelection()
    }
  }

  public duplicateSelectedElements = (): void => {
    const selectedElements = this.getSelectedElements()
    if (selectedElements.length > 0) {
      const newElements = selectedElements.map(el => ({
        ...el,
        id: `${Date.now()}-${Math.random()}`,
        x: el.x + 20,
        y: el.y + 20,
        created: Date.now(),
        updated: Date.now(),
      }))

      const elements = [...this.elements$.getSnapshot(), ...newElements]
      this.elements$.next(elements)

      // Select the duplicated elements
      this.selectElements(newElements.map(el => el.id))
    }
  }

  public zoomToFit = (): void => {
    const elements = this.elements$.getSnapshot()
    if (elements.length === 0) return

    // Calculate bounding box of all elements
    let minX = Infinity,
      minY = Infinity,
      maxX = -Infinity,
      maxY = -Infinity

    elements.forEach(el => {
      minX = Math.min(minX, el.x)
      minY = Math.min(minY, el.y)
      maxX = Math.max(maxX, el.x + (el.width || 100))
      maxY = Math.max(maxY, el.y + (el.height || 100))
    })

    const padding = 50
    const contentWidth = maxX - minX + padding * 2
    const contentHeight = maxY - minY + padding * 2

    // Assuming canvas size (you might want to pass this as a parameter)
    const canvasWidth = window.innerWidth
    const canvasHeight = window.innerHeight

    const zoomX = canvasWidth / contentWidth
    const zoomY = canvasHeight / contentHeight
    const zoom = Math.min(zoomX, zoomY, 1) // Don't zoom in beyond 100%

    this.setZoom(zoom)

    // Center the content
    const centerX = (minX + maxX) / 2
    const centerY = (minY + maxY) / 2
    const offsetX = canvasWidth / 2 - centerX * zoom
    const offsetY = canvasHeight / 2 - centerY * zoom

    const viewData = this.viewData$.getSnapshot()
    this.viewData$.next({
      ...viewData,
      offsetX,
      offsetY,
    })
  }
}
