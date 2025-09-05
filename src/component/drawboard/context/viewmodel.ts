import { State, ViewModel } from '@guanghechen/viewmodel'
import type { IState } from '@guanghechen/viewmodel'
import type { DrawboardElement } from '../types/elements'
import type { IDrawboardAppState, IDrawboardViewData, ToolMode } from './types'

interface IProps {
  mode?: ToolMode
  onSave?: (elements: DrawboardElement[]) => void
}

const DEFAULT_VIEW_DATA: IDrawboardViewData = {
  mode: 1, // ToolMode.SELECT
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
  selectedTool: 1, // ToolMode.SELECT
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
  }

  // Element management
  public addElement = (element: DrawboardElement): void => {
    const elements = [...this.elements$.getSnapshot(), element]
    this.elements$.next(elements)
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
  }

  public deleteElements = (ids: string[]): void => {
    const idSet = new Set(ids)
    const elements = this.elements$.getSnapshot().filter(el => !idSet.has(el.id))
    this.elements$.next(elements)
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
    this.mode$.next(tool)
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, selectedTool: tool })
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

  public setBackgroundColor = (color: string): void => {
    const appState = this.appState$.getSnapshot()
    this.appState$.next({ ...appState, currentItemBackgroundColor: color })
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
}
