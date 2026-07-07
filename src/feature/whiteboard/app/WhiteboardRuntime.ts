import {
  IdFactory,
  WHITEBOARD_ZOOM,
  createEmptyWhiteboardDocumentData,
} from '@/feature/whiteboard/model'
import type { IWhiteboardDocument, IWhiteboardDocumentData } from '@/feature/whiteboard/model'
import type { IWhiteboardRenderer } from '@/feature/whiteboard/renderer'
import { WebGLRendererStub } from '@/feature/whiteboard/renderer'
import { ComputeEventQueue } from '@/feature/whiteboard/runtime'
import type { IComputeEvent, IComputePayloadMap } from '@/feature/whiteboard/runtime'
import {
  CommandBus,
  HistoryStore,
  type IClipboardSnapshot,
  type IEdgeValidationIssue,
  SceneStore,
  createBringForwardCommand,
  createBringToFrontCommand,
  createClipboardSnapshotFromSelection,
  createCreateEdgeCommand,
  createCreateNodeCommand,
  createDeleteNodesCommand,
  createPasteClipboardCommand,
  createSendBackwardCommand,
  createSendToBackCommand,
  createSetViewportCommand,
  createUpdateNodePayloadCommand,
  moveNodesByDelta,
  resizeNodeTo,
  validateEdgeConnection,
} from '@/feature/whiteboard/store'

export interface IWhiteboardPointerInput {
  readonly x: number
  readonly y: number
  readonly button: number
  readonly spaceKey?: boolean
  readonly shiftKey?: boolean
}

export interface IWhiteboardWheelInput {
  readonly x: number
  readonly y: number
  readonly deltaY: number
}

export type IWhiteboardInteractionMode =
  'idle' | 'drag-node' | 'resize-node' | 'lasso-select' | 'pan' | 'connect-edge'

export interface IEdgeValidationDetail {
  readonly edgeId: string
  readonly level: 'ok' | 'warn' | 'error'
  readonly issues: ReadonlyArray<IEdgeValidationIssue>
}

export interface INodeValidationIssue {
  readonly code: string
  readonly severity: 'warn' | 'error'
  readonly message: string
}

export interface INodeValidationDetail {
  readonly nodeId: string
  readonly level: 'ok' | 'warn' | 'error'
  readonly issues: ReadonlyArray<INodeValidationIssue>
}

export interface IWhiteboardViewState {
  readonly snapshot: IWhiteboardDocument
  readonly selectedNodeIds: ReadonlyArray<string>
  readonly interactionMode: IWhiteboardInteractionMode
  readonly canUndo: boolean
  readonly canRedo: boolean
  readonly statusMessage: string | null
  readonly edgeValidationSummary: {
    readonly warnCount: number
    readonly errorCount: number
  }
  readonly nodeValidationSummary: {
    readonly warnCount: number
    readonly errorCount: number
  }
  readonly edgeValidationDetails: ReadonlyArray<IEdgeValidationDetail>
  readonly nodeValidationDetails: ReadonlyArray<INodeValidationDetail>
  readonly clipboard: {
    readonly hasData: boolean
    readonly nodeCount: number
  }
}

export interface IWhiteboardRuntimeOptions {
  readonly initialData?: IWhiteboardDocumentData
  readonly renderer?: IWhiteboardRenderer
}

interface IDragNodeState {
  readonly nodeIds: ReadonlyArray<string>
  readonly startWorldX: number
  readonly startWorldY: number
  readonly lastWorldX: number
  readonly lastWorldY: number
}

interface IResizeNodeState {
  readonly nodeId: string
  readonly startWorldX: number
  readonly startWorldY: number
  readonly originWidth: number
  readonly originHeight: number
}

interface ILassoState {
  readonly startCanvasX: number
  readonly startCanvasY: number
  readonly currentCanvasX: number
  readonly currentCanvasY: number
  readonly appendMode: boolean
}

interface IPanState {
  readonly startCanvasX: number
  readonly startCanvasY: number
  readonly originOffsetX: number
  readonly originOffsetY: number
}

interface IConnectEdgeState {
  readonly fromPortId: string
  readonly fromNodeId: string
  readonly pointerX: number
  readonly pointerY: number
  readonly isTargetValid: boolean
}

interface ICanvasRect {
  readonly x: number
  readonly y: number
  readonly width: number
  readonly height: number
}

const normalizeCanvasRect = (x1: number, y1: number, x2: number, y2: number): ICanvasRect => {
  const left = Math.min(x1, x2)
  const top = Math.min(y1, y2)
  return {
    x: left,
    y: top,
    width: Math.abs(x2 - x1),
    height: Math.abs(y2 - y1),
  }
}

export class WhiteboardRuntime {
  public readonly sceneStore: SceneStore
  public readonly historyStore: HistoryStore
  public readonly commandBus: CommandBus
  public readonly computeEventQueue: ComputeEventQueue
  public readonly renderer: IWhiteboardRenderer

  private readonly listeners = new Set<(state: IWhiteboardViewState) => void>()
  private selectedNodeIds: string[] = []
  private interactionMode: IWhiteboardInteractionMode = 'idle'
  private dragNodeState: IDragNodeState | null = null
  private resizeNodeState: IResizeNodeState | null = null
  private lassoState: ILassoState | null = null
  private panState: IPanState | null = null
  private connectEdgeState: IConnectEdgeState | null = null
  private sceneUnsubscribe: (() => void) | null = null
  private canvasWidth = 1280
  private canvasHeight = 720
  private statusMessage: string | null = null
  private nodeValidationById: Record<string, 'ok' | 'warn' | 'error'> = {}
  private nodeValidationDetailById: Record<string, INodeValidationDetail> = {}
  private edgeValidationById: Record<string, 'ok' | 'warn' | 'error'> = {}
  private edgeValidationDetailById: Record<string, IEdgeValidationDetail> = {}
  private clipboardSnapshot: IClipboardSnapshot | null = null

  constructor(options: IWhiteboardRuntimeOptions = {}) {
    const initialData =
      options.initialData ?? createEmptyWhiteboardDocumentData('Untitled Whiteboard')

    this.sceneStore = new SceneStore(initialData)
    this.historyStore = new HistoryStore()
    this.commandBus = new CommandBus(this.sceneStore, this.historyStore)
    this.computeEventQueue = new ComputeEventQueue()
    this.renderer = options.renderer ?? new WebGLRendererStub()

    this.sceneUnsubscribe = this.sceneStore.subscribe(() => {
      this.enqueueRevalidateAll('manual', 'command_bus')
      this.processPriorityQueue()
      this.renderNow()
      this.emit()
    })

    this.enqueueRevalidateAll('load', 'system')
    this.processPriorityQueue()
  }

  public attach(canvas: HTMLCanvasElement): void {
    this.renderer.attach(canvas)
    this.resize(canvas.clientWidth, canvas.clientHeight, globalThis.devicePixelRatio || 1)
    this.renderNow()
  }

  public resize(width: number, height: number, dpr: number): void {
    this.canvasWidth = Math.max(1, width)
    this.canvasHeight = Math.max(1, height)
    this.renderer.resize(width, height, dpr)
    this.renderNow()
  }

  public dispose(): void {
    this.cancelInteraction()
    this.sceneUnsubscribe?.()
    this.sceneUnsubscribe = null
    this.renderer.dispose()
    this.listeners.clear()
  }

  public subscribe(listener: (state: IWhiteboardViewState) => void): () => void {
    this.listeners.add(listener)
    listener(this.getViewState())

    return (): void => {
      this.listeners.delete(listener)
    }
  }

  public getViewState(): IWhiteboardViewState {
    const nodeValidationSummary = this.getNodeValidationSummary()
    const nodeValidationDetails = Object.values(this.nodeValidationDetailById).sort((a, b) => {
      if (a.level === b.level) return a.nodeId.localeCompare(b.nodeId)
      if (a.level === 'error') return -1
      if (b.level === 'error') return 1
      if (a.level === 'warn') return -1
      if (b.level === 'warn') return 1
      return 0
    })

    const edgeValidationSummary = this.getEdgeValidationSummary()
    const edgeValidationDetails = Object.values(this.edgeValidationDetailById).sort((a, b) => {
      if (a.level === b.level) return a.edgeId.localeCompare(b.edgeId)
      if (a.level === 'error') return -1
      if (b.level === 'error') return 1
      if (a.level === 'warn') return -1
      if (b.level === 'warn') return 1
      return 0
    })

    return {
      snapshot: this.sceneStore.getSnapshot(),
      selectedNodeIds: this.selectedNodeIds,
      interactionMode: this.interactionMode,
      canUndo: this.commandBus.canUndo(),
      canRedo: this.commandBus.canRedo(),
      statusMessage: this.statusMessage,
      nodeValidationSummary,
      nodeValidationDetails,
      edgeValidationSummary,
      edgeValidationDetails,
      clipboard: {
        hasData: this.clipboardSnapshot !== null,
        nodeCount: this.clipboardSnapshot?.nodes.length ?? 0,
      },
    }
  }

  public createShapeNodeAtViewportCenter(
    type: string = 'shape.rectangle',
    payload: Record<string, unknown> = {},
  ): void {
    const snapshot = this.sceneStore.getSnapshot()
    const viewport = snapshot.data.graph.viewport
    const centerWorldX = (this.canvasWidth * 0.5 - viewport.offsetX) / viewport.zoom
    const centerWorldY = (this.canvasHeight * 0.5 - viewport.offsetY) / viewport.zoom
    const nodeId = IdFactory.createNodeId()

    this.commandBus.execute(
      createCreateNodeCommand({
        id: nodeId,
        type,
        x: centerWorldX - 110,
        y: centerWorldY - 60,
        payload,
      }),
    )

    this.setSelectedNodeIds([nodeId])
  }

  public undo(): void {
    const undone = this.commandBus.undo()
    if (!undone) return

    this.setSelectedNodeIds([])
  }

  public redo(): void {
    const redone = this.commandBus.redo()
    if (!redone) return

    this.setSelectedNodeIds([])
  }

  public zoomByFactor(factor: number, anchorX?: number, anchorY?: number): void {
    const snapshot = this.sceneStore.getSnapshot()
    const viewport = snapshot.data.graph.viewport

    const screenX = anchorX ?? this.canvasWidth * 0.5
    const screenY = anchorY ?? this.canvasHeight * 0.5

    const nextZoom = Math.max(
      WHITEBOARD_ZOOM.MIN,
      Math.min(WHITEBOARD_ZOOM.MAX, viewport.zoom * factor),
    )
    if (nextZoom === viewport.zoom) return

    const worldX = (screenX - viewport.offsetX) / viewport.zoom
    const worldY = (screenY - viewport.offsetY) / viewport.zoom

    const offsetX = screenX - worldX * nextZoom
    const offsetY = screenY - worldY * nextZoom

    this.commandBus.execute(
      createSetViewportCommand({
        zoom: nextZoom,
        offsetX,
        offsetY,
      }),
    )
  }

  public resetViewport(): void {
    this.commandBus.execute(
      createSetViewportCommand({
        zoom: 1,
        offsetX: 0,
        offsetY: 0,
      }),
    )
  }

  public toggleGrid(): void {
    const viewport = this.sceneStore.getSnapshot().data.graph.viewport
    this.commandBus.execute(
      createSetViewportCommand({
        showGrid: !viewport.showGrid,
      }),
    )
  }

  public updateNodePayload(nodeId: string, payloadPatch: Record<string, unknown>): void {
    this.commandBus.execute(createUpdateNodePayloadCommand(nodeId, payloadPatch))
  }

  public deleteSelectedNodes(): void {
    if (this.selectedNodeIds.length === 0) return

    this.commandBus.execute(createDeleteNodesCommand(this.selectedNodeIds))
    this.setSelectedNodeIds([])
  }

  public selectAllNodes(): void {
    const nodeIds = Object.values(this.sceneStore.getSnapshot().data.graph.nodesById)
      .filter(node => node.status.visibility === 'visible')
      .map(node => node.id)

    this.setSelectedNodeIds(nodeIds)
  }

  public clearSelection(): void {
    this.setSelectedNodeIds([])
  }

  public getNodeIdAtCanvasPoint(x: number, y: number): string | null {
    const hit = this.renderer.pick({ x, y })
    if (hit?.hitType !== 'node' || !hit.hitId) return null

    return hit.hitId
  }

  public copySelection(): void {
    if (this.selectedNodeIds.length === 0) {
      this.statusMessage = 'Nothing selected to copy'
      this.emit()
      return
    }

    const snapshot = createClipboardSnapshotFromSelection(
      this.sceneStore.getSnapshot().data,
      this.selectedNodeIds,
    )
    if (snapshot.nodes.length === 0) {
      this.statusMessage = 'Selection cannot be copied'
      this.emit()
      return
    }

    this.clipboardSnapshot = snapshot
    this.statusMessage = `Copied ${snapshot.nodes.length} node(s)`
    this.emit()
  }

  public pasteClipboard(offsetX: number = 36, offsetY: number = 24): void {
    if (!this.clipboardSnapshot) {
      this.statusMessage = 'Clipboard is empty'
      this.emit()
      return
    }

    const beforeNodeIds = new Set(Object.keys(this.sceneStore.getSnapshot().data.graph.nodesById))
    this.commandBus.execute(createPasteClipboardCommand(this.clipboardSnapshot, offsetX, offsetY))

    const afterNodeIds = Object.keys(this.sceneStore.getSnapshot().data.graph.nodesById)
    const pastedNodeIds = afterNodeIds.filter(nodeId => !beforeNodeIds.has(nodeId))
    this.setSelectedNodeIds(pastedNodeIds)
    this.statusMessage = `Pasted ${pastedNodeIds.length} node(s)`
    this.emit()
  }

  public duplicateSelection(): void {
    this.copySelection()
    if (!this.clipboardSnapshot) return
    this.pasteClipboard(48, 32)
  }

  public bringSelectionToFront(): void {
    if (this.selectedNodeIds.length === 0) return
    this.commandBus.execute(createBringToFrontCommand(this.selectedNodeIds))
  }

  public sendSelectionToBack(): void {
    if (this.selectedNodeIds.length === 0) return
    this.commandBus.execute(createSendToBackCommand(this.selectedNodeIds))
  }

  public bringSelectionForward(): void {
    if (this.selectedNodeIds.length === 0) return
    this.commandBus.execute(createBringForwardCommand(this.selectedNodeIds))
  }

  public sendSelectionBackward(): void {
    if (this.selectedNodeIds.length === 0) return
    this.commandBus.execute(createSendBackwardCommand(this.selectedNodeIds))
  }

  public handlePointerDown(input: IWhiteboardPointerInput): void {
    if (input.button === 1 || (input.button === 0 && input.spaceKey)) {
      this.beginPan(input)
      return
    }

    if (input.button !== 0) return

    const hit = this.renderer.pick({ x: input.x, y: input.y })

    if (hit?.hitType === 'port' && hit.hitId) {
      const port = this.sceneStore.getSnapshot().data.graph.portsById[hit.hitId]
      if (!port || port.direction === 'input') {
        this.statusMessage = 'Please start from an output or bidirectional port'
        this.emit()
        return
      }

      this.interactionMode = 'connect-edge'
      this.connectEdgeState = {
        fromPortId: port.id,
        fromNodeId: port.nodeId,
        pointerX: input.x,
        pointerY: input.y,
        isTargetValid: false,
      }
      this.statusMessage = 'Connecting edge... release on a compatible input port'
      this.emit()
      return
    }

    if (hit?.hitType === 'node' && hit.hitId) {
      const node = this.sceneStore.getSnapshot().data.graph.nodesById[hit.hitId]
      if (!node || node.status.locked) return

      if (input.shiftKey) {
        this.toggleSelectionNode(hit.hitId)
        this.statusMessage = null
        this.emit()
        return
      }

      const nextSelection = this.selectedNodeIds.includes(hit.hitId)
        ? this.selectedNodeIds
        : [hit.hitId]
      this.setSelectedNodeIds(nextSelection)

      if (nextSelection.length === 1 && this.isPointerOnResizeHandle(node, input.x, input.y)) {
        this.beginResize(node.id, input)
        return
      }

      this.beginDrag(nextSelection, input)
      return
    }

    this.beginLasso(input)
  }

  public handlePointerMove(input: IWhiteboardPointerInput): void {
    if (this.connectEdgeState) {
      const hit = this.renderer.pick({ x: input.x, y: input.y })
      this.enqueueEdgeDragValidate(
        this.connectEdgeState.fromNodeId,
        this.connectEdgeState.fromPortId,
        input.x,
        input.y,
        hit?.hitType === 'port' ? hit.hitId : undefined,
      )
      this.processRealtimeQueue()
      this.renderNow()
      this.emit()
      return
    }

    if (this.lassoState) {
      this.lassoState = {
        ...this.lassoState,
        currentCanvasX: input.x,
        currentCanvasY: input.y,
      }
      this.renderNow()
      this.emit()
      return
    }

    if (this.resizeNodeState) {
      const world = this.canvasToWorld(input.x, input.y)
      const deltaX = world.x - this.resizeNodeState.startWorldX
      const deltaY = world.y - this.resizeNodeState.startWorldY

      this.commandBus.updateDraft(data => {
        return resizeNodeTo(
          data,
          this.resizeNodeState!.nodeId,
          this.resizeNodeState!.originWidth + deltaX,
          this.resizeNodeState!.originHeight + deltaY,
        )
      })
      return
    }

    if (this.dragNodeState) {
      const world = this.canvasToWorld(input.x, input.y)
      const deltaX = world.x - this.dragNodeState.lastWorldX
      const deltaY = world.y - this.dragNodeState.lastWorldY
      if (deltaX === 0 && deltaY === 0) return

      this.dragNodeState = {
        ...this.dragNodeState,
        lastWorldX: world.x,
        lastWorldY: world.y,
      }

      this.commandBus.updateDraft(data =>
        moveNodesByDelta(data, this.dragNodeState!.nodeIds, deltaX, deltaY),
      )
      return
    }

    if (this.panState) {
      const nextOffsetX = this.panState.originOffsetX + (input.x - this.panState.startCanvasX)
      const nextOffsetY = this.panState.originOffsetY + (input.y - this.panState.startCanvasY)

      this.commandBus.updateDraft(data =>
        createSetViewportCommand({ offsetX: nextOffsetX, offsetY: nextOffsetY }).apply(data),
      )
      return
    }
  }

  public handlePointerUp(input?: IWhiteboardPointerInput): void {
    if (this.connectEdgeState) {
      const hit = input ? this.renderer.pick({ x: input.x, y: input.y }) : null
      if (hit?.hitType === 'port' && hit.hitId) {
        const result = validateEdgeConnection(
          this.sceneStore.getSnapshot().data,
          this.connectEdgeState.fromPortId,
          hit.hitId,
        )

        if (result.canCreate) {
          const beforeEdgeIds = new Set(
            Object.keys(this.sceneStore.getSnapshot().data.graph.edgesById),
          )
          this.commandBus.execute(
            createCreateEdgeCommand({
              fromPortId: this.connectEdgeState.fromPortId,
              toPortId: hit.hitId,
              routing: 'bezier',
            }),
          )
          const afterEdgeIds = Object.keys(this.sceneStore.getSnapshot().data.graph.edgesById)
          const createdEdgeId = afterEdgeIds.find(edgeId => !beforeEdgeIds.has(edgeId))
          if (createdEdgeId) {
            this.enqueueRevalidateScope({
              edgeIds: [createdEdgeId],
              reason: 'command',
            })
            this.processPriorityQueue()
          }
          this.statusMessage = 'Edge created'
        } else {
          this.statusMessage = result.issues[0]?.message ?? 'Failed to create edge'
        }
      } else {
        this.statusMessage = 'Edge creation canceled'
      }

      this.connectEdgeState = null
      this.interactionMode = 'idle'
      this.renderNow()
      this.emit()
      return
    }

    if (this.lassoState) {
      const rect = normalizeCanvasRect(
        this.lassoState.startCanvasX,
        this.lassoState.startCanvasY,
        this.lassoState.currentCanvasX,
        this.lassoState.currentCanvasY,
      )
      const selectedIds = this.findNodesInCanvasRect(rect)

      if (this.lassoState.appendMode) {
        this.setSelectedNodeIds([...new Set([...this.selectedNodeIds, ...selectedIds])])
      } else {
        this.setSelectedNodeIds(selectedIds)
      }

      this.lassoState = null
      this.interactionMode = 'idle'
      this.statusMessage = `Selected ${selectedIds.length} node(s)`
      this.renderNow()
      this.emit()
      return
    }

    if (this.resizeNodeState) {
      this.resizeNodeState = null
      this.interactionMode = 'idle'
      this.commandBus.commitTransaction('Resize node')
      this.emit()
      return
    }

    if (this.dragNodeState) {
      this.dragNodeState = null
      this.interactionMode = 'idle'
      this.commandBus.commitTransaction('Move node')
      this.emit()
      return
    }

    if (this.panState) {
      this.panState = null
      this.interactionMode = 'idle'
      this.commandBus.commitTransaction('Pan viewport')
      this.emit()
    }
  }

  public handleWheel(input: IWhiteboardWheelInput): void {
    const zoomFactor = input.deltaY > 0 ? 1 / 1.08 : 1.08
    this.zoomByFactor(zoomFactor, input.x, input.y)
  }

  public cancelInteraction(): void {
    if (this.connectEdgeState) {
      this.connectEdgeState = null
      this.interactionMode = 'idle'
      this.statusMessage = null
      this.renderNow()
      this.emit()
      return
    }

    if (this.lassoState) {
      this.lassoState = null
      this.interactionMode = 'idle'
      this.statusMessage = null
      this.renderNow()
      this.emit()
      return
    }

    if (!this.commandBus.hasActiveTransaction()) return

    this.commandBus.rollbackTransaction()
    this.dragNodeState = null
    this.resizeNodeState = null
    this.panState = null
    this.interactionMode = 'idle'
    this.emit()
  }

  public renderNow(): void {
    const scene = this.sceneStore.getSnapshot().graph
    this.renderer.prepare(scene)
    this.renderer.render({
      timestamp: Date.now(),
      invalidatedLayers: ['paper', 'grid', 'edge', 'node', 'overlay', 'hud'],
      selectedNodeIds: this.selectedNodeIds,
      nodeValidationById: this.nodeValidationById,
      edgeValidationById: this.edgeValidationById,
      selectionBox: this.lassoState
        ? normalizeCanvasRect(
            this.lassoState.startCanvasX,
            this.lassoState.startCanvasY,
            this.lassoState.currentCanvasX,
            this.lassoState.currentCanvasY,
          )
        : undefined,
      draftEdge: this.connectEdgeState
        ? {
            fromPortId: this.connectEdgeState.fromPortId,
            toX: this.connectEdgeState.pointerX,
            toY: this.connectEdgeState.pointerY,
            valid: this.connectEdgeState.isTargetValid,
          }
        : undefined,
    })
  }

  private enqueueRevalidateAll(
    reason: IComputePayloadMap['REVALIDATE_ALL']['reason'],
    source: 'command_bus' | 'system' | 'storage_recovery' | 'importer',
  ): void {
    const event = this.computeEventQueue.createEvent({
      type: 'REVALIDATE_ALL',
      priority: 'normal',
      payload: { reason },
      from: {
        source,
        traceId: IdFactory.createTraceId(),
      },
    })
    this.computeEventQueue.enqueue(event)
  }

  private enqueueRevalidateScope(payload: IComputePayloadMap['REVALIDATE_SCOPE']): void {
    const event = this.computeEventQueue.createEvent({
      type: 'REVALIDATE_SCOPE',
      priority: 'high',
      payload,
      from: {
        source: 'command_bus',
        traceId: IdFactory.createTraceId(),
      },
    })
    this.computeEventQueue.enqueue(event)
  }

  private enqueueEdgeDragValidate(
    fromNodeId: string,
    fromPortId: string,
    pointerCanvasX: number,
    pointerCanvasY: number,
    candidateToPortId?: string,
  ): void {
    const event = this.computeEventQueue.createEvent({
      type: 'EDGE_DRAG_VALIDATE',
      priority: 'realtime',
      payload: {
        fromNodeId,
        fromPortId,
        pointerCanvasX,
        pointerCanvasY,
        candidateToPortId,
      },
      from: {
        source: 'tool',
        activeId: fromPortId,
        traceId: IdFactory.createTraceId(),
      },
    })

    this.computeEventQueue.enqueue(event)
  }

  private processRealtimeQueue(): void {
    this.computeEventQueue.drainRealtime(event => {
      this.handleComputeEvent(event)
    })
  }

  private processPriorityQueue(): void {
    this.computeEventQueue.drainPriority(
      event => {
        this.handleComputeEvent(event)
      },
      { budgetMs: 4 },
    )
  }

  private handleComputeEvent(event: IComputeEvent): void {
    switch (event.type) {
      case 'EDGE_DRAG_VALIDATE': {
        this.applyEdgeDragValidation(event.payload as IComputePayloadMap['EDGE_DRAG_VALIDATE'])
        return
      }
      case 'REVALIDATE_ALL': {
        this.revalidateAllEdges()
        return
      }
      case 'REVALIDATE_SCOPE': {
        this.revalidateScope(event.payload as IComputePayloadMap['REVALIDATE_SCOPE'])
        return
      }
      default:
        return
    }
  }

  private applyEdgeDragValidation(payload: IComputePayloadMap['EDGE_DRAG_VALIDATE']): void {
    if (!this.connectEdgeState) return
    if (this.connectEdgeState.fromPortId !== payload.fromPortId) return

    let isTargetValid = false
    if (payload.candidateToPortId) {
      const result = validateEdgeConnection(
        this.sceneStore.getSnapshot().data,
        payload.fromPortId,
        payload.candidateToPortId,
      )
      isTargetValid = result.canCreate
    }

    this.connectEdgeState = {
      ...this.connectEdgeState,
      pointerX: payload.pointerCanvasX,
      pointerY: payload.pointerCanvasY,
      isTargetValid,
    }
  }

  private revalidateAllEdges(): void {
    const data = this.sceneStore.getSnapshot().data
    const nextNodeMap: Record<string, 'ok' | 'warn' | 'error'> = {}
    const nextNodeDetails: Record<string, INodeValidationDetail> = {}

    for (const node of Object.values(data.graph.nodesById)) {
      const issues = this.validateNode(node)
      const level: 'ok' | 'warn' | 'error' = issues.some(issue => issue.severity === 'error')
        ? 'error'
        : issues.some(issue => issue.severity === 'warn')
          ? 'warn'
          : 'ok'

      nextNodeMap[node.id] = level
      nextNodeDetails[node.id] = {
        nodeId: node.id,
        level,
        issues,
      }
    }

    const nextMap: Record<string, 'ok' | 'warn' | 'error'> = {}
    const nextDetails: Record<string, IEdgeValidationDetail> = {}

    for (const edge of Object.values(data.graph.edgesById)) {
      const result = validateEdgeConnection(data, edge.from.portId, edge.to.portId, {
        ignoreEdgeId: edge.id,
      })

      let level: 'ok' | 'warn' | 'error' = 'ok'
      if (result.issues.some(issue => issue.severity === 'error')) {
        level = 'error'
      } else if (result.issues.some(issue => issue.severity === 'warn')) {
        level = 'warn'
      }

      nextMap[edge.id] = level
      nextDetails[edge.id] = {
        edgeId: edge.id,
        level,
        issues: result.issues,
      }
    }

    this.nodeValidationById = nextNodeMap
    this.nodeValidationDetailById = nextNodeDetails
    this.edgeValidationById = nextMap
    this.edgeValidationDetailById = nextDetails
  }

  private revalidateScope(payload: IComputePayloadMap['REVALIDATE_SCOPE']): void {
    const hasEdgeIds = Boolean(payload.edgeIds && payload.edgeIds.length > 0)
    const hasNodeIds = Boolean(payload.nodeIds && payload.nodeIds.length > 0)

    if (!hasEdgeIds && !hasNodeIds) {
      this.revalidateAllEdges()
      return
    }

    const data = this.sceneStore.getSnapshot().data
    let nextNodeMap = { ...this.nodeValidationById }
    let nextNodeDetails = { ...this.nodeValidationDetailById }

    const nodeIds = payload.nodeIds
      ? [...payload.nodeIds]
      : payload.edgeIds
        ? this.resolveNodeIdsByEdgeIds(payload.edgeIds)
        : []

    for (const nodeId of nodeIds) {
      const node = data.graph.nodesById[nodeId]
      if (!node) {
        nextNodeMap = Object.fromEntries(
          Object.entries(nextNodeMap).filter(([key]) => key !== nodeId),
        ) as typeof nextNodeMap
        nextNodeDetails = Object.fromEntries(
          Object.entries(nextNodeDetails).filter(([key]) => key !== nodeId),
        ) as typeof nextNodeDetails
        continue
      }

      const issues = this.validateNode(node)
      const level: 'ok' | 'warn' | 'error' = issues.some(issue => issue.severity === 'error')
        ? 'error'
        : issues.some(issue => issue.severity === 'warn')
          ? 'warn'
          : 'ok'

      nextNodeMap[node.id] = level
      nextNodeDetails[node.id] = {
        nodeId: node.id,
        level,
        issues,
      }
    }

    let nextMap = { ...this.edgeValidationById }
    let nextDetails = { ...this.edgeValidationDetailById }

    for (const edgeId of payload.edgeIds ?? []) {
      const edge = data.graph.edgesById[edgeId]
      if (!edge) {
        nextMap = Object.fromEntries(
          Object.entries(nextMap).filter(([key]) => key !== edgeId),
        ) as typeof nextMap
        nextDetails = Object.fromEntries(
          Object.entries(nextDetails).filter(([key]) => key !== edgeId),
        ) as typeof nextDetails
        continue
      }

      const result = validateEdgeConnection(data, edge.from.portId, edge.to.portId, {
        ignoreEdgeId: edge.id,
      })

      const level: 'ok' | 'warn' | 'error' = result.issues.some(issue => issue.severity === 'error')
        ? 'error'
        : result.issues.some(issue => issue.severity === 'warn')
          ? 'warn'
          : 'ok'

      nextMap[edge.id] = level
      nextDetails[edge.id] = {
        edgeId: edge.id,
        level,
        issues: result.issues,
      }
    }

    this.nodeValidationById = nextNodeMap
    this.nodeValidationDetailById = nextNodeDetails
    this.edgeValidationById = nextMap
    this.edgeValidationDetailById = nextDetails
  }

  private resolveNodeIdsByEdgeIds(edgeIds: ReadonlyArray<string>): string[] {
    const data = this.sceneStore.getSnapshot().data
    const nodeIdSet = new Set<string>()

    for (const edgeId of edgeIds) {
      const edge = data.graph.edgesById[edgeId]
      if (!edge) continue

      nodeIdSet.add(edge.from.nodeId)
      nodeIdSet.add(edge.to.nodeId)
    }

    return [...nodeIdSet]
  }

  private validateNode(
    node: IWhiteboardDocument['data']['graph']['nodesById'][string],
  ): ReadonlyArray<INodeValidationIssue> {
    if (node.type !== 'node.image') {
      return []
    }

    const source = String(node.payload.src ?? '').trim()
    if (source.length === 0) {
      return [
        {
          code: 'IMAGE_SOURCE_EMPTY',
          severity: 'warn',
          message: 'Image node source is empty',
        },
      ]
    }

    const isHttpUrl = /^https?:\/\/[\w.-]+(?::[0-9]+)?(?:\/[^\s]*)?$/i.test(source)
    const hasScheme = /^[a-zA-Z][a-zA-Z\d+.-]*:\/\//.test(source)
    const isRelativePath = !hasScheme && !source.startsWith('/') && !/^[a-zA-Z]:[\\/]/.test(source)
    const isAbsolutePath =
      /^\//.test(source) || /^[a-zA-Z]:[\\/]/.test(source) || source.startsWith('file://')

    const issues: INodeValidationIssue[] = []
    if (isAbsolutePath) {
      issues.push({
        code: 'IMAGE_SOURCE_ABSOLUTE_PATH',
        severity: 'warn',
        message: 'Absolute local paths are discouraged; use URL or relative path',
      })
    }

    if (!isHttpUrl && !isRelativePath) {
      issues.push({
        code: 'IMAGE_SOURCE_FORMAT_INVALID',
        severity: 'warn',
        message: 'Image source should be a URL or relative path',
      })
    }

    return issues
  }

  private getNodeValidationSummary(): { warnCount: number; errorCount: number } {
    let warnCount = 0
    let errorCount = 0

    for (const level of Object.values(this.nodeValidationById)) {
      if (level === 'warn') {
        warnCount += 1
      } else if (level === 'error') {
        errorCount += 1
      }
    }

    return {
      warnCount,
      errorCount,
    }
  }

  private getEdgeValidationSummary(): { warnCount: number; errorCount: number } {
    let warnCount = 0
    let errorCount = 0

    for (const level of Object.values(this.edgeValidationById)) {
      if (level === 'warn') {
        warnCount += 1
      } else if (level === 'error') {
        errorCount += 1
      }
    }

    return {
      warnCount,
      errorCount,
    }
  }

  private beginDrag(nodeIds: ReadonlyArray<string>, input: IWhiteboardPointerInput): void {
    if (nodeIds.length === 0) return

    const world = this.canvasToWorld(input.x, input.y)
    this.interactionMode = 'drag-node'
    this.dragNodeState = {
      nodeIds,
      startWorldX: world.x,
      startWorldY: world.y,
      lastWorldX: world.x,
      lastWorldY: world.y,
    }
    this.commandBus.beginTransaction('Move node')
    this.emit()
  }

  private beginResize(nodeId: string, input: IWhiteboardPointerInput): void {
    const node = this.sceneStore.getSnapshot().data.graph.nodesById[nodeId]
    if (!node) return

    const world = this.canvasToWorld(input.x, input.y)
    this.interactionMode = 'resize-node'
    this.resizeNodeState = {
      nodeId,
      startWorldX: world.x,
      startWorldY: world.y,
      originWidth: node.dimension.width,
      originHeight: node.dimension.height,
    }
    this.commandBus.beginTransaction('Resize node')
    this.emit()
  }

  private beginLasso(input: IWhiteboardPointerInput): void {
    this.interactionMode = 'lasso-select'
    this.lassoState = {
      startCanvasX: input.x,
      startCanvasY: input.y,
      currentCanvasX: input.x,
      currentCanvasY: input.y,
      appendMode: Boolean(input.shiftKey),
    }

    this.statusMessage = input.shiftKey ? 'Lasso append selection' : 'Lasso selecting'
    if (!input.shiftKey) {
      this.setSelectedNodeIds([])
    } else {
      this.renderNow()
      this.emit()
    }
  }

  private toggleSelectionNode(nodeId: string): void {
    if (this.selectedNodeIds.includes(nodeId)) {
      this.setSelectedNodeIds(this.selectedNodeIds.filter(id => id !== nodeId))
      return
    }

    this.setSelectedNodeIds([...this.selectedNodeIds, nodeId])
  }

  private isPointerOnResizeHandle(
    node: IWhiteboardDocument['data']['graph']['nodesById'][string],
    x: number,
    y: number,
  ): boolean {
    const viewport = this.sceneStore.getSnapshot().data.graph.viewport
    const handleSize = 14

    const handleX =
      (node.dimension.x + node.dimension.width) * viewport.zoom +
      viewport.offsetX -
      handleSize * 0.5
    const handleY =
      (node.dimension.y + node.dimension.height) * viewport.zoom +
      viewport.offsetY -
      handleSize * 0.5

    return x >= handleX && x <= handleX + handleSize && y >= handleY && y <= handleY + handleSize
  }

  private findNodesInCanvasRect(rect: ICanvasRect): ReadonlyArray<string> {
    const viewport = this.sceneStore.getSnapshot().data.graph.viewport
    const worldRect: ICanvasRect = {
      x: (rect.x - viewport.offsetX) / viewport.zoom,
      y: (rect.y - viewport.offsetY) / viewport.zoom,
      width: rect.width / viewport.zoom,
      height: rect.height / viewport.zoom,
    }

    const ids: string[] = []
    for (const node of Object.values(this.sceneStore.getSnapshot().data.graph.nodesById)) {
      if (node.status.visibility === 'hidden') continue

      const intersects =
        node.dimension.x <= worldRect.x + worldRect.width &&
        node.dimension.x + node.dimension.width >= worldRect.x &&
        node.dimension.y <= worldRect.y + worldRect.height &&
        node.dimension.y + node.dimension.height >= worldRect.y

      if (intersects) {
        ids.push(node.id)
      }
    }

    return ids
  }

  private beginPan(input: IWhiteboardPointerInput): void {
    if (this.commandBus.hasActiveTransaction()) return

    const viewport = this.sceneStore.getSnapshot().data.graph.viewport
    this.interactionMode = 'pan'
    this.panState = {
      startCanvasX: input.x,
      startCanvasY: input.y,
      originOffsetX: viewport.offsetX,
      originOffsetY: viewport.offsetY,
    }

    this.commandBus.beginTransaction('Pan viewport')
    this.emit()
  }

  private canvasToWorld(x: number, y: number): { x: number; y: number } {
    const viewport = this.sceneStore.getSnapshot().data.graph.viewport
    return {
      x: (x - viewport.offsetX) / viewport.zoom,
      y: (y - viewport.offsetY) / viewport.zoom,
    }
  }

  private setSelectedNodeIds(nextIds: ReadonlyArray<string>): void {
    const next = [...nextIds]
    if (
      this.selectedNodeIds.length === next.length &&
      this.selectedNodeIds.every((value, index) => value === next[index])
    ) {
      return
    }

    this.selectedNodeIds = next
    this.renderNow()
    this.emit()
  }

  private emit(): void {
    const state = this.getViewState()
    for (const listener of this.listeners) {
      listener(state)
    }
  }
}
