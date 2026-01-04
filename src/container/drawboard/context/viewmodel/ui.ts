import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { IState } from '@guanghechen/react-viewmodel'
import type { IDrawboardElement } from '../../types/elements'
import { animationFrameManager, easingFunctions } from '../../util/performance'
import { ToolMode } from '../types'

export interface IUIConfig {
  readonly backgroundColor: string
  readonly strokeColor: string
  readonly fillColor: string
  readonly fillStyle: string
  readonly strokeWidth: number
  readonly strokeStyle: string
  readonly roughness: number
  readonly opacity: number
  readonly font: string
}

export const DEFAULT_UI_CONFIG: IUIConfig = {
  backgroundColor: '#ffffff',
  strokeColor: '#000000',
  fillColor: 'transparent',
  fillStyle: 'solid',
  strokeWidth: 2,
  strokeStyle: 'solid',
  roughness: 1,
  opacity: 100,
  font: 'Virgil, Segoe UI Emoji',
} as const

export interface IInteractionState {
  readonly cursorButton: 'up' | 'down'
  readonly scrolledOutside: boolean
  readonly zoom: { value: number }
  readonly offsetX: number
  readonly offsetY: number
  // CSS transform coordinates for smooth dragging
  readonly transformOffsetX: number
  readonly transformOffsetY: number
  readonly transformZoom: number
  readonly openMenu: string | null
  readonly lastPointerDownWith: 'mouse' | 'touch' | 'pen'
  readonly isPanning: boolean
}

export const DEFAULT_INTERACTION_STATE: IInteractionState = {
  cursorButton: 'up',
  scrolledOutside: false,
  zoom: { value: 1 },
  offsetX: 0,
  offsetY: 0,
  transformOffsetX: 0,
  transformOffsetY: 0,
  transformZoom: 1,
  openMenu: null,
  lastPointerDownWith: 'mouse',
  isPanning: false,
} as const

interface IProps {
  readonly mode?: ToolMode
  readonly uiConfig?: Partial<IUIConfig>
  readonly interactionState?: Partial<IInteractionState>
}

export class UIViewModel extends ViewModel {
  // Tool state
  public readonly selectedTool$: IState<ToolMode>
  public readonly lastActiveTool$: IState<ToolMode | null>
  public readonly toolLocked$: IState<boolean>

  // Selection state
  public readonly selectedElementIds$: IState<Record<string, boolean>>

  // Individual UI config states
  public readonly backgroundColor$: IState<string>
  public readonly strokeColor$: IState<string>
  public readonly fillColor$: IState<string>
  public readonly fillStyle$: IState<string>
  public readonly strokeWidth$: IState<number>
  public readonly strokeStyle$: IState<string>
  public readonly roughness$: IState<number>
  public readonly opacity$: IState<number>
  public readonly font$: IState<string>

  // Interaction state
  public readonly interactionState$: IState<IInteractionState>

  constructor(props: IProps = {}) {
    super()

    const { mode = ToolMode.SELECT, uiConfig = {}, interactionState = {} } = props
    const finalUIConfig = { ...DEFAULT_UI_CONFIG, ...uiConfig }

    // Initialize tool state
    this.selectedTool$ = new State<ToolMode>(mode)
    this.lastActiveTool$ = new State<ToolMode | null>(null)
    this.toolLocked$ = new State<boolean>(false)

    // Initialize selection state
    this.selectedElementIds$ = new State<Record<string, boolean>>({})

    // Initialize individual UI config states
    this.backgroundColor$ = new State<string>(finalUIConfig.backgroundColor)
    this.strokeColor$ = new State<string>(finalUIConfig.strokeColor)
    this.fillColor$ = new State<string>(finalUIConfig.fillColor)
    this.fillStyle$ = new State<string>(finalUIConfig.fillStyle)
    this.strokeWidth$ = new State<number>(finalUIConfig.strokeWidth)
    this.strokeStyle$ = new State<string>(finalUIConfig.strokeStyle)
    this.roughness$ = new State<number>(finalUIConfig.roughness)
    this.opacity$ = new State<number>(finalUIConfig.opacity)
    this.font$ = new State<string>(finalUIConfig.font)

    // Initialize interaction state
    this.interactionState$ = new State<IInteractionState>({
      ...DEFAULT_INTERACTION_STATE,
      ...interactionState,
    })
  }

  // Tool management
  public setTool = (tool: ToolMode): void => {
    const currentTool = this.selectedTool$.getSnapshot()
    const lastActiveTool = [ToolMode.SELECT, ToolMode.LASSO, ToolMode.PAN].includes(currentTool)
      ? this.lastActiveTool$.getSnapshot()
      : currentTool

    this.selectedTool$.next(tool)
    this.lastActiveTool$.next(lastActiveTool)
  }

  public toggleToolLock = (): void => {
    const currentLocked = this.toolLocked$.getSnapshot()
    this.toolLocked$.next(!currentLocked)
  }

  public switchToLastActiveTool = (): void => {
    const lastActiveTool = this.lastActiveTool$.getSnapshot()
    if (lastActiveTool) {
      this.setTool(lastActiveTool)
    }
  }

  // Selection management
  public getSelectedElements = (elements: IDrawboardElement[]): IDrawboardElement[] => {
    const selectedIds = this.selectedElementIds$.getSnapshot()
    return elements.filter(el => selectedIds[el.id])
  }

  public selectElements = (ids: string[]): void => {
    const selectedElementIds: Record<string, boolean> = {}
    ids.forEach(id => {
      selectedElementIds[id] = true
    })
    this.selectedElementIds$.next(selectedElementIds)
  }

  public clearSelection = (): void => {
    this.selectedElementIds$.next({})
  }

  public toggleElementSelection = (id: string): void => {
    const selectedIds = this.selectedElementIds$.getSnapshot()
    const newSelection = { ...selectedIds }

    if (newSelection[id]) {
      const { [id]: _, ...rest } = newSelection
      this.selectedElementIds$.next(rest)
    } else {
      this.selectedElementIds$.next({ ...newSelection, [id]: true })
    }
  }

  public isSelected = (id: string): boolean => {
    const selectedIds = this.selectedElementIds$.getSnapshot()
    return !!selectedIds[id]
  }

  public duplicateSelectedElements = (
    elements: IDrawboardElement[],
    onDuplicate: (duplicatedElements: IDrawboardElement[]) => void,
  ): void => {
    const selectedIds = this.selectedElementIds$.getSnapshot()
    const selectedElements = elements.filter(el => selectedIds[el.id])

    if (selectedElements.length === 0) return

    const duplicatedElements: IDrawboardElement[] = selectedElements.map(element => ({
      ...structuredClone(element),
      id: `${element.id}_copy_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`,
      x: element.x + 20,
      y: element.y + 20,
    }))

    onDuplicate(duplicatedElements)

    const newSelectedIds: Record<string, boolean> = {}
    duplicatedElements.forEach(element => {
      newSelectedIds[element.id] = true
    })
    this.selectedElementIds$.next(newSelectedIds)
  }

  public deleteSelectedElements = (
    elements: IDrawboardElement[],
    onDelete: (remainingElements: IDrawboardElement[]) => void,
  ): void => {
    const selectedIds = this.selectedElementIds$.getSnapshot()
    const remainingElements = elements.filter(el => !selectedIds[el.id])

    this.clearSelection()
    onDelete(remainingElements)
  }

  // Transform-based pan/zoom methods for smooth dragging with hardware acceleration
  public setTransformOffset = (transformOffsetX: number, transformOffsetY: number): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, transformOffsetX, transformOffsetY })
  }

  public setTransformZoom = (transformZoom: number): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, transformZoom })
  }

  public animateZoom = (
    targetZoom: number,
    duration = 300,
    centerX?: number,
    centerY?: number,
  ): void => {
    const state = this.interactionState$.getSnapshot()
    const currentZoom = state.zoom.value

    if (Math.abs(currentZoom - targetZoom) < 0.01) return

    // Calculate center point for zoom (default to center of viewport)
    const zoomCenterX = centerX ?? 0
    const zoomCenterY = centerY ?? 0

    animationFrameManager.animate(
      'zoom-animation',
      currentZoom,
      targetZoom,
      duration,
      easingFunctions.easeOut,
      (zoomValue: number) => {
        // Calculate offset adjustment to maintain zoom center
        const zoomDelta = zoomValue - currentZoom
        const offsetAdjustmentX = -zoomCenterX * zoomDelta
        const offsetAdjustmentY = -zoomCenterY * zoomDelta

        // Update both zoom and offset for smooth centered zoom
        const currentState = this.interactionState$.getSnapshot()
        this.interactionState$.next({
          ...currentState,
          zoom: { value: zoomValue },
          transformZoom: zoomValue,
          offsetX: currentState.offsetX + offsetAdjustmentX,
          offsetY: currentState.offsetY + offsetAdjustmentY,
          transformOffsetX: currentState.transformOffsetX + offsetAdjustmentX,
          transformOffsetY: currentState.transformOffsetY + offsetAdjustmentY,
        })
      },
      () => {
        // Ensure final values are exactly the target
        const finalState = this.interactionState$.getSnapshot()
        this.interactionState$.next({
          ...finalState,
          zoom: { value: targetZoom },
          transformZoom: targetZoom,
        })
      },
    )
  }

  public startPanning = (): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({
      ...state,
      isPanning: true,
      // Initialize transform coordinates with current logical coordinates
      transformOffsetX: state.offsetX,
      transformOffsetY: state.offsetY,
      transformZoom: state.zoom.value,
    })
  }

  public updateTransformDuringPan = (deltaX: number, deltaY: number): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({
      ...state,
      transformOffsetX: state.transformOffsetX + deltaX,
      transformOffsetY: state.transformOffsetY + deltaY,
    })
  }

  public finishPanning = (): void => {
    const state = this.interactionState$.getSnapshot()
    // Commit transform coordinates to logical coordinates
    this.interactionState$.next({
      ...state,
      offsetX: state.transformOffsetX,
      offsetY: state.transformOffsetY,
      zoom: { value: state.transformZoom },
      isPanning: false,
    })
  }

  // Interaction state management with smooth animations
  public setZoom = (zoom: number, animated = false, centerX?: number, centerY?: number): void => {
    if (animated) {
      this.animateZoom(zoom, 300, centerX, centerY)
    } else {
      const state = this.interactionState$.getSnapshot()
      this.interactionState$.next({ ...state, zoom: { value: zoom } })
    }
  }

  public setOffset = (offsetX: number, offsetY: number): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, offsetX, offsetY })
  }

  public pan = (deltaX: number, deltaY: number): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({
      ...state,
      offsetX: state.offsetX + deltaX,
      offsetY: state.offsetY + deltaY,
    })
  }

  public setCursorButton = (cursorButton: 'up' | 'down'): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, cursorButton })
  }

  public setScrolledOutside = (scrolledOutside: boolean): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, scrolledOutside })
  }

  public setOpenMenu = (openMenu: string | null): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, openMenu })
  }

  public setLastPointerDownWith = (lastPointerDownWith: 'mouse' | 'touch' | 'pen'): void => {
    const state = this.interactionState$.getSnapshot()
    this.interactionState$.next({ ...state, lastPointerDownWith })
  }

  public zoomToFit = (
    elements: IDrawboardElement[],
    canvasWidth = 800,
    canvasHeight = 600,
    padding = 50,
    animated = true,
  ): void => {
    if (elements.length === 0) {
      if (animated) {
        this.animateZoom(1)
        // Animate to center as well
        animationFrameManager.animate(
          'pan-to-center',
          0,
          1,
          300,
          easingFunctions.easeOut,
          (progress: number) => {
            const state = this.interactionState$.getSnapshot()
            this.interactionState$.next({
              ...state,
              offsetX: state.offsetX * (1 - progress),
              offsetY: state.offsetY * (1 - progress),
              transformOffsetX: state.transformOffsetX * (1 - progress),
              transformOffsetY: state.transformOffsetY * (1 - progress),
            })
          },
        )
      } else {
        this.setZoom(1)
        this.setOffset(0, 0)
      }
      return
    }

    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity

    elements.forEach(element => {
      const { x, y, width = 100, height = 100 } = element
      minX = Math.min(minX, x)
      minY = Math.min(minY, y)
      maxX = Math.max(maxX, x + width)
      maxY = Math.max(maxY, y + height)
    })

    const contentWidth = maxX - minX
    const contentHeight = maxY - minY

    const availableWidth = canvasWidth - padding * 2
    const availableHeight = canvasHeight - padding * 2
    const zoomX = availableWidth / contentWidth
    const zoomY = availableHeight / contentHeight
    const newZoom = Math.min(zoomX, zoomY, 1)

    const contentCenterX = (minX + maxX) / 2
    const contentCenterY = (minY + maxY) / 2
    const canvasCenterX = canvasWidth / 2
    const canvasCenterY = canvasHeight / 2

    const newOffsetX = canvasCenterX - contentCenterX * newZoom
    const newOffsetY = canvasCenterY - contentCenterY * newZoom

    if (animated) {
      const currentState = this.interactionState$.getSnapshot()

      // Animate zoom
      this.animateZoom(newZoom)

      // Animate pan
      animationFrameManager.animate(
        'pan-to-fit',
        0,
        1,
        300,
        easingFunctions.easeOut,
        (progress: number) => {
          const interpolatedOffsetX =
            currentState.offsetX + (newOffsetX - currentState.offsetX) * progress
          const interpolatedOffsetY =
            currentState.offsetY + (newOffsetY - currentState.offsetY) * progress

          const state = this.interactionState$.getSnapshot()
          this.interactionState$.next({
            ...state,
            offsetX: interpolatedOffsetX,
            offsetY: interpolatedOffsetY,
            transformOffsetX: interpolatedOffsetX,
            transformOffsetY: interpolatedOffsetY,
          })
        },
      )
    } else {
      this.setZoom(newZoom)
      this.setOffset(newOffsetX, newOffsetY)
    }
  }
}
