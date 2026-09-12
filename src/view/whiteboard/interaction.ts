import React from 'react'
import {
  attachEndpoint,
  boundsBetween,
  duplicateElements,
  edgeEndpointAt,
  elementBounds,
  hitElements,
  hitTest,
  intersects,
  moveElements,
  reconnectEdge,
  resolveEndpoint,
  unionBounds,
  worldPoint,
  zoomAt,
} from '@/shared/whiteboard/geometry'
import { parseDocument } from '@/shared/whiteboard/document'
import { createDocument } from '@/shared/whiteboard/model'
import { expandSelection } from '@/shared/whiteboard/organization'
import {
  resizeBounds,
  resizeCornerAt,
  resizeElements,
  rotateElements,
  transformBounds,
  transformPivot,
} from '@/shared/whiteboard/transforms'
import { framePoint, rotatePoint, rotationHandle } from '@/shared/whiteboard/pose'
import type { ITransformFrame } from '@/shared/whiteboard/pose'
import { connectorControlAt, connectorControls } from '@/shared/whiteboard/edges'
import {
  constrainAngle,
  drawingBounds,
  prepareMoveSnap,
  snapMove,
} from '@/shared/whiteboard/drawing'
import type { IAlignmentGuide, IMoveSnap } from '@/shared/whiteboard/drawing'
import type {
  IBounds,
  ICamera,
  IEdge,
  IEdgeAppearance,
  IElement,
  INode,
  IPoint,
  IStyle,
} from '@/shared/whiteboard/model'
import type { BoardStore } from './store'
import { removeElements } from '@/shared/whiteboard/commands'
import { eraseAlong } from '@/shared/whiteboard/erasing'
import { orderedDocument } from '@/shared/whiteboard/stacking'
import { touchCamera } from '@/shared/whiteboard/navigation'
import type { IHitTestOptions } from '@/shared/whiteboard/geometry'
import type { BoardTypography } from './typography'
import { TOOLS } from './tools'
import type { ITool } from './tools'

interface IDrag {
  pointerId: number
  kind:
    | 'pan'
    | 'move'
    | 'resize'
    | 'rotate'
    | 'reconnect'
    | 'control'
    | 'erase'
    | 'marquee'
    | 'draw'
    | 'laser'
  start: IPoint
  screen: IPoint
  camera: ICamera
  elements: ReadonlyArray<IElement>
  selected: ReadonlySet<string>
  bounds?: ITransformFrame
  pivot?: IPoint
  startAngle?: number
  erased?: ReadonlySet<string>
  erasePoint?: IPoint
  hitOptions?: IHitTestOptions
  edge?: IEdge
  endpoint?: 'from' | 'to'
  controlIndex?: number
  corner?: IPoint
  created?: IElement
  points: IPoint[]
  snap?: IMoveSnap | null
}

export function createNode(tool: ITool, point: IPoint, style: IStyle): INode {
  const base = { id: crypto.randomUUID(), x: point.x, y: point.y, width: 180, height: 120, style }
  if (tool === 'markdown')
    return {
      ...base,
      type: 'markdown',
      width: 360,
      height: 260,
      source: {
        kind: 'inline',
        content: '# A new idea\n\nDouble-click to edit.\n\n- Connect ideas\n- Explore the details',
      },
    }
  if (tool === 'text')
    return { ...base, type: 'text', width: 260, height: 100, text: 'Your idea', autoSize: true }
  if (tool === 'image')
    return {
      ...base,
      type: 'image',
      width: 320,
      height: 220,
      url: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+a9XkAAAAASUVORK5CYII=',
    }
  if (tool === 'stroke')
    return {
      ...base,
      type: 'stroke',
      points: [
        { x: 0, y: 0 },
        { x: 1, y: 1 },
      ],
    }
  return {
    ...base,
    type: 'shape',
    shape: tool === 'ellipse' || tool === 'diamond' ? tool : 'rectangle',
  }
}

export const BOARD_DIALOG_SELECTOR = '.wb-editor,.wb-label-editor,.wb-reference,[aria-modal="true"]'

const typing = (target: EventTarget | null): boolean =>
  target instanceof Element &&
  !!target.closest(
    'input,textarea,select,dialog,[contenteditable="true"],.monaco-editor,[role="dialog"],[role="menu"]',
  )

const MOVE_DIRECTIONS: Readonly<Record<string, IPoint | undefined>> = {
  arrowleft: { x: -1, y: 0 },
  arrowright: { x: 1, y: 0 },
  arrowup: { x: 0, y: -1 },
  arrowdown: { x: 0, y: 1 },
}

export function useBoardInteraction(
  stage: React.RefObject<HTMLDivElement | null>,
  store: BoardStore,
  tool: ITool,
  style: IStyle,
  setTool: (tool: ITool) => void,
  edit: (element: IElement) => void,
  message: (text: string) => void,
  locked: boolean,
  toggleLock: () => void,
  importImages: (files: ReadonlyArray<File>, center: IPoint) => void,
  edgeAppearance: IEdgeAppearance,
  typography: BoardTypography,
  readOnly: boolean,
  laser: (point: IPoint) => void,
) {
  const readOnlyRef = React.useRef(readOnly)
  readOnlyRef.current = readOnly
  const touches = React.useRef(new Map<number, IPoint>())
  const pinch = React.useRef<{ camera: ICamera; start: IPoint[]; ids: number[] } | null>(null)
  const touchPan = React.useRef<{ camera: ICamera; start: IPoint; id: number } | null>(null)
  const suppressClick = React.useRef(0)
  const [contextMenu, setContextMenu] = React.useState<{
    x: number
    y: number
    point: IPoint
    targets: IElement[]
  } | null>(null)
  const closeContextMenu = React.useCallback(() => setContextMenu(null), [])
  const mounted = React.useRef(true)
  React.useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])
  const [marquee, setMarquee] = React.useState<IBounds>()
  const [guides, setGuides] = React.useState<ReadonlyArray<IAlignmentGuide>>([])
  const [rotationPreview, setRotationPreview] = React.useState<ITransformFrame>()
  const marqueeRef = React.useRef<IBounds | undefined>(undefined)
  const drag = React.useRef<IDrag | null>(null)
  const space = React.useRef(false)
  const frame = React.useRef(0)
  const pending = React.useRef<{ point: IPoint; shift: boolean; alt: boolean } | null>(null)
  const lastPointer = React.useRef<IPoint | null>(null)
  const moveKeys = React.useRef(new Set<string>())
  const isInteracting = React.useCallback(
    () =>
      drag.current !== null ||
      moveKeys.current.size > 0 ||
      pinch.current !== null ||
      touchPan.current !== null,
    [],
  )
  const local = React.useCallback(
    (event: { clientX: number; clientY: number }): IPoint => {
      const rect = stage.current!.getBoundingClientRect()
      return { x: event.clientX - rect.left, y: event.clientY - rect.top }
    },
    [stage],
  )

  const finishKeyMove = (cancel = false): void => {
    if (!moveKeys.current.size) return
    moveKeys.current.clear()
    if (cancel) store.cancel()
    else store.commit()
  }

  const cardReceivesPointer = React.useCallback(
    (event: { target: EventTarget | null; clientX: number; clientY: number }): boolean => {
      const card =
        event.target instanceof Element ? event.target.closest<HTMLElement>('.wb-card') : null
      if (!card) return false
      const snapshot = store.getSnapshot()
      return (
        hitTest(
          snapshot.document.elements,
          worldPoint(local(event), snapshot.camera),
          0,
          false,
          typography.labelBounds,
          { includeLocked: true, locked: snapshot.locked, hidden: snapshot.hidden },
        )?.id === card.dataset.nodeId
      )
    },
    [local, store, typography],
  )

  const pasteValue = (value: string, at?: IPoint): void => {
    if (readOnlyRef.current) return
    try {
      const current = store.getSnapshot()
      let elements: ReadonlyArray<IElement>
      if (value.trim().startsWith('{') && value.includes('yoz.whiteboard')) {
        const source = orderedDocument(parseDocument(value))
        elements = duplicateElements(
          source.elements,
          new Set(source.elements.map(element => element.id)),
        )
        if (at) {
          const map = new Map(elements.map(element => [element.id, element]))
          const bounds = unionBounds(elements.map(element => elementBounds(element, map)))
          if (bounds)
            elements = moveElements(elements, new Set(elements.map(element => element.id)), {
              x: at.x - bounds.x - bounds.width / 2,
              y: at.y - bounds.y - bounds.height / 2,
            })
        }
      } else {
        const point =
          at ??
          worldPoint(
            { x: stage.current!.clientWidth / 2, y: stage.current!.clientHeight / 2 },
            current.camera,
          )
        elements = [
          {
            ...createNode('markdown', point, style),
            type: 'markdown',
            source: { kind: 'inline', content: value },
          },
        ]
      }
      store.commit(
        parseDocument(
          JSON.stringify({
            ...current.document,
            elements: [...current.document.elements, ...elements],
          }),
        ),
      )
      store.select(new Set(elements.map(element => element.id)))
    } catch (error) {
      message(error instanceof Error ? error.message : String(error))
    }
  }

  const copyToClipboard = async (cut = false): Promise<void> => {
    finishKeyMove()
    const initial = store.getSnapshot()
    if (!initial.selected.size || (cut && (readOnlyRef.current || !store.canRemoveSelection())))
      return
    try {
      const elements = duplicateElements(initial.document.elements, initial.selected)
      await navigator.clipboard.writeText(JSON.stringify({ ...createDocument(), elements }))
      if (!mounted.current) return
      if (cut) {
        const current = store.getSnapshot()
        if (
          readOnlyRef.current ||
          isInteracting() ||
          window.document.querySelector(BOARD_DIALOG_SELECTOR) ||
          current.document !== initial.document ||
          store.getDocument() !== initial.document ||
          current.selected.size !== initial.selected.size ||
          [...initial.selected].some(id => !current.selected.has(id))
        )
          throw new Error(
            'Selection changed while copying. Copied data was kept; cut again to remove it.',
          )
        store.removeSelected()
      }
    } catch (error) {
      if (mounted.current)
        message(
          error instanceof Error
            ? error.message
            : 'Clipboard unavailable; use the keyboard shortcut',
        )
    }
  }

  const pasteFromClipboard = async (point: IPoint): Promise<void> => {
    if (readOnlyRef.current) return
    finishKeyMove()
    const initial = store.getDocument()
    try {
      let text = ''
      const files: File[] = []
      if (navigator.clipboard.read) {
        for (const item of await navigator.clipboard.read()) {
          const type = item.types.find(type => type.startsWith('image/'))
          if (type) files.push(new File([await item.getType(type)], 'clipboard-image', { type }))
          else if (!text && item.types.includes('text/plain'))
            text = await (await item.getType('text/plain')).text()
        }
      } else text = await navigator.clipboard.readText()
      if (!mounted.current) return
      if (
        readOnlyRef.current ||
        store.getDocument() !== initial ||
        store.getSnapshot().document !== initial ||
        isInteracting() ||
        window.document.querySelector(BOARD_DIALOG_SELECTOR)
      )
        throw new Error('Whiteboard changed while reading the clipboard. Paste again.')
      if (files.length) importImages(files, point)
      else if (text) pasteValue(text, point)
    } catch (error) {
      if (mounted.current)
        message(
          error instanceof Error
            ? error.message
            : 'Clipboard unavailable; use the keyboard shortcut',
        )
    }
  }

  const update = (screen: IPoint, preserveAspect: boolean, alt: boolean): void => {
    const active = drag.current
    if (!active) return
    const point = worldPoint(screen, active.camera)
    if (active.kind === 'laser') {
      laser(screen)
    } else if (active.kind === 'pan') {
      store.camera({
        ...active.camera,
        x: active.camera.x + screen.x - active.screen.x,
        y: active.camera.y + screen.y - active.screen.y,
      })
    } else if (
      active.kind === 'rotate' &&
      active.bounds &&
      active.pivot &&
      active.startAngle !== undefined
    ) {
      let degrees =
        ((Math.atan2(point.y - active.pivot.y, point.x - active.pivot.x) - active.startAngle) *
          180) /
        Math.PI
      const base = active.bounds.rotation ?? 0
      if (preserveAspect) degrees = Math.round((base + degrees) / 15) * 15 - base
      const center = rotatePoint(
        {
          x: active.bounds.x + active.bounds.width / 2,
          y: active.bounds.y + active.bounds.height / 2,
        },
        active.pivot,
        degrees,
      )
      setRotationPreview({
        x: center.x - active.bounds.width / 2,
        y: center.y - active.bounds.height / 2,
        width: active.bounds.width,
        height: active.bounds.height,
        rotation: base + degrees,
      })
      store.preview(rotateElements(active.elements, active.selected, degrees, active.pivot))
    } else if (active.kind === 'erase' && active.erased && active.hitOptions) {
      if (
        active.erasePoint &&
        Math.hypot(screen.x - active.erasePoint.x, screen.y - active.erasePoint.y) < 0.001
      )
        return
      const from = worldPoint(active.erasePoint ?? screen, active.camera)
      const removed = eraseAlong(
        active.elements,
        from,
        point,
        active.camera.zoom,
        active.erased,
        active.hitOptions,
        typography.labelBounds,
      )
      active.erasePoint = screen
      if (removed !== active.erased) {
        active.erased = removed
        store.preview(removeElements(active.elements, removed))
      }
    } else if (active.kind === 'move') {
      const delta = { x: point.x - active.start.x, y: point.y - active.start.y }
      const moved = Math.hypot(screen.x - active.screen.x, screen.y - active.screen.y) >= 2
      const snapped =
        moved && !alt && active.snap
          ? snapMove(active.snap, delta, 6 / active.camera.zoom)
          : { delta: moved ? delta : { x: 0, y: 0 }, guides: [] }
      setGuides(snapped.guides)
      store.preview(moveElements(active.elements, active.selected, snapped.delta))
    } else if (active.kind === 'reconnect' && active.edge && active.endpoint) {
      const edge = reconnectEdge(
        active.edge,
        active.endpoint,
        point,
        active.elements,
        12 / active.camera.zoom,
      )
      store.preview(active.elements.map(element => (element.id === edge.id ? edge : element)))
    } else if (active.kind === 'control' && active.edge && active.controlIndex !== undefined) {
      const map = new Map(active.elements.map(element => [element.id, element]))
      const controls = connectorControls(
        active.edge,
        resolveEndpoint(active.edge.from, map),
        resolveEndpoint(active.edge.to, map),
      )
      const updated = {
        ...active.edge,
        controls: controls.map((control, index) =>
          index === active.controlIndex ? { ...control, ...point } : control,
        ),
      }
      store.preview(active.elements.map(element => (element.id === updated.id ? updated : element)))
    } else if (active.kind === 'resize' && active.bounds && active.corner) {
      const corner = framePoint(active.bounds, active.corner)
      store.preview(
        resizeElements(
          active.elements,
          active.selected,
          active.bounds,
          active.corner,
          {
            x: corner.x + point.x - active.start.x,
            y: corner.y + point.y - active.start.y,
          },
          preserveAspect,
        ),
      )
    } else if (active.kind === 'marquee') {
      marqueeRef.current = boundsBetween(active.start, point)
      setMarquee(marqueeRef.current)
    } else if (active.created) {
      let created = active.created
      if (created.type === 'edge') {
        const hit = hitTest(active.elements, point, 12 / active.camera.zoom, true)
        created = {
          ...created,
          to: preserveAspect
            ? constrainAngle(
                resolveEndpoint(
                  created.from,
                  new Map(active.elements.map(item => [item.id, item])),
                ),
                point,
              )
            : attachEndpoint(hit?.type !== 'edge' ? hit : undefined, point),
        }
      } else if (created.type === 'stroke') {
        const last = active.points.at(-1)!
        if (Math.hypot(last.x - point.x, last.y - point.y) > 1 / active.camera.zoom)
          active.points.push(point)
        const xs = active.points.map(p => p.x),
          ys = active.points.map(p => p.y)
        const bounds = boundsBetween(
          { x: Math.min(...xs), y: Math.min(...ys) },
          { x: Math.max(...xs), y: Math.max(...ys) },
        )
        const points =
          active.points.length === 1 ? [active.points[0], active.points[0]] : active.points
        created = {
          ...created,
          ...bounds,
          points: points.map(p => ({
            x: (p.x - bounds.x) / bounds.width,
            y: (p.y - bounds.y) / bounds.height,
          })),
        }
      } else if (created.type === 'shape') {
        created = { ...created, ...drawingBounds(active.start, point, preserveAspect, alt) }
      }
      store.preview([...active.elements, created])
    }
  }
  const finish = (cancel = false): void => {
    cancelAnimationFrame(frame.current)
    frame.current = 0
    const released = pending.current
    if (released && !cancel) update(released.point, released.shift, released.alt)
    pending.current = null
    lastPointer.current = null
    const active = drag.current
    drag.current = null
    if (!active) return
    if (cancel) {
      store.cancel()
      if (active.created) store.select(active.selected)
    } else if (active.kind === 'marquee') {
      const selected = new Set(active.selected)
      const map = new Map(active.elements.map(item => [item.id, item]))
      if (
        marqueeRef.current &&
        released &&
        Math.hypot(released.point.x - active.screen.x, released.point.y - active.screen.y) >= 2
      )
        for (const item of active.elements)
          if (
            !store.getSnapshot().hidden.has(item.id) &&
            !store.getSnapshot().locked.has(item.id) &&
            intersects(elementBounds(item, map), marqueeRef.current)
          )
            selected.add(item.id)
      store.select(selected)
    } else if (active.kind !== 'pan' && active.kind !== 'laser') {
      // A click with a shape tool creates a useful default size.
      const current = store.getSnapshot().document
      store.commit({
        ...current,
        elements: current.elements.map(item =>
          item.id === active.created?.id &&
          item.type === 'shape' &&
          item.width < 8 &&
          item.height < 8
            ? {
                ...item,
                ...drawingBounds(
                  active.start,
                  {
                    x: active.start.x + 180 / (released?.alt ? 2 : 1),
                    y: active.start.y + 120 / (released?.alt ? 2 : 1),
                  },
                  !!released?.shift,
                  !!released?.alt,
                ),
              }
            : item,
        ),
      })
      if (active.created && active.created.type !== 'stroke' && !locked) setTool('select')
    }
    setGuides([])
    setRotationPreview(undefined)
    setMarquee(undefined)
    marqueeRef.current = undefined
  }

  const scheduleUpdate = (point: IPoint, shift: boolean, alt: boolean): void => {
    lastPointer.current = point
    pending.current = { point, shift, alt }
    if (frame.current) return
    frame.current = requestAnimationFrame(() => {
      frame.current = 0
      const next = pending.current
      pending.current = null
      if (next) update(next.point, next.shift, next.alt)
    })
  }

  React.useEffect(() => {
    const element = stage.current
    if (!element) return
    const wheel = (event: WheelEvent): void => {
      if (typing(event.target)) return
      const card =
        event.target instanceof Element ? event.target.closest<HTMLElement>('[data-node-id]') : null
      if (
        card &&
        (readOnly || store.getSnapshot().selected.has(card.dataset.nodeId!)) &&
        !event.ctrlKey &&
        !event.metaKey &&
        !event.shiftKey &&
        (event.target as Element).closest('[data-card-content]') &&
        cardReceivesPointer(event)
      )
        return
      event.preventDefault()
      const camera = store.getSnapshot().camera
      if (event.ctrlKey || event.metaKey)
        store.camera(zoomAt(camera, local(event), camera.zoom * Math.exp(-event.deltaY * 0.008)))
      else store.camera({ ...camera, x: camera.x - event.deltaX, y: camera.y - event.deltaY })
    }
    element.addEventListener('wheel', wheel, { passive: false })
    return () => element.removeEventListener('wheel', wheel)
  }, [stage, store, local, cardReceivesPointer, readOnly])

  React.useEffect(() => {
    const keydown = (event: KeyboardEvent): void => {
      if (typing(event.target) || document.querySelector(BOARD_DIALOG_SELECTOR)) return
      const command = event.ctrlKey || event.metaKey
      const key = event.key.toLowerCase()
      if (pinch.current || touchPan.current) {
        if (command || MOVE_DIRECTIONS[key]) event.preventDefault()
        return
      }
      if (readOnly) {
        const direction = MOVE_DIRECTIONS[key]
        if (direction && !command) {
          event.preventDefault()
          const camera = store.getSnapshot().camera
          const amount = event.shiftKey ? 100 : 40
          store.camera({
            ...camera,
            x: camera.x - direction.x * amount,
            y: camera.y - direction.y * amount,
          })
        } else if (event.code === 'Space') {
          event.preventDefault()
          space.current = true
        } else if (key === 'escape') {
          finish(true)
          setTool('hand')
        } else if (!command && ['h', 'v', 'l'].includes(key))
          setTool(key === 'l' ? 'laser' : 'hand')
        else if (command && key === 'a') {
          event.preventDefault()
          const snapshot = store.getSnapshot()
          store.select(
            new Set(
              snapshot.document.elements.filter(e => !snapshot.hidden.has(e.id)).map(e => e.id),
            ),
          )
        } else if (
          (command && ['z', 'y', 'd', 'g', 'x', 'v', '[', ']'].includes(key)) ||
          ['delete', 'backspace', 'enter'].includes(key)
        )
          event.preventDefault()
        return
      }
      if (drag.current && lastPointer.current && (key === 'shift' || key === 'alt')) {
        event.preventDefault()
        scheduleUpdate(lastPointer.current, event.shiftKey, event.altKey)
        return
      }
      const direction = MOVE_DIRECTIONS[key]
      if (direction && !command && !event.altKey) {
        const snapshot = store.getSnapshot()
        if (drag.current || !snapshot.selected.size) return
        event.preventDefault()
        if (!store.canEditSelection()) return
        if (event.repeat && !moveKeys.current.has(key)) return
        moveKeys.current.add(key)
        const step = event.shiftKey ? 10 : 1
        store.preview(
          moveElements(snapshot.document.elements, snapshot.selected, {
            x: direction.x * step,
            y: direction.y * step,
          }),
        )
        return
      }
      if (!['shift', 'control', 'meta', 'alt'].includes(key)) finishKeyMove(key === 'escape')
      if (event.code === 'Space') {
        event.preventDefault()
        space.current = true
        return
      }
      if (key === 'escape') {
        finish(true)
        setTool('select')
        return
      }
      if (command && key === 'z') {
        event.preventDefault()
        finish(true)
        if (event.shiftKey) store.redo()
        else store.undo()
        return
      }
      if (drag.current) {
        if (command || key === 'delete' || key === 'backspace') event.preventDefault()
        return
      }
      if (command && key === 'y') {
        event.preventDefault()
        store.redo()
        return
      }
      const snapshot = store.getSnapshot()
      if (command && key === 'a') {
        event.preventDefault()
        store.select(
          new Set(
            snapshot.document.elements
              .filter(item => !snapshot.hidden.has(item.id) && !snapshot.locked.has(item.id))
              .map(item => item.id),
          ),
        )
        return
      }
      if (command && key === 'd') {
        event.preventDefault()
        store.duplicateSelected()
        return
      }
      if (command && key === 'g') {
        event.preventDefault()
        finish(true)
        if (event.shiftKey) store.ungroupSelected()
        else store.groupSelected()
        return
      }
      if (command && !event.altKey && snapshot.selected.size) {
        const backward = event.code === 'BracketLeft' || key === '[' || key === '{'
        const forward = event.code === 'BracketRight' || key === ']' || key === '}'
        if (backward || forward) {
          event.preventDefault()
          store.reorderSelected(
            backward
              ? event.shiftKey
                ? 'back'
                : 'backward'
              : event.shiftKey
                ? 'front'
                : 'forward',
          )
          return
        }
      }
      if (command && event.shiftKey && key === 'l' && snapshot.selected.size) {
        event.preventDefault()
        store.setSelectedFlags({
          locked: ![...snapshot.selected].some(id => snapshot.locked.has(id)),
        })
        return
      }
      if (key === 'delete' || key === 'backspace') {
        event.preventDefault()
        store.removeSelected()
        return
      }
      if (key === 'enter' && snapshot.selected.size === 1) {
        const node = snapshot.document.elements.find(item => snapshot.selected.has(item.id))
        if (node && node.type !== 'stroke') {
          event.preventDefault()
          edit(node)
        }
      }
      if (!command && !event.altKey) {
        if (key === 'q') {
          event.preventDefault()
          if (!event.repeat) toggleLock()
          return
        }
        const next = TOOLS.find(item => item.key.toLowerCase() === key)
        if (next) setTool(next.id)
      }
    }
    const keyup = (event: KeyboardEvent): void => {
      if (drag.current && lastPointer.current && ['Shift', 'Alt'].includes(event.key))
        scheduleUpdate(lastPointer.current, event.shiftKey, event.altKey)
      if (event.code === 'Space') space.current = false
      if (moveKeys.current.delete(event.key.toLowerCase()) && !moveKeys.current.size) store.commit()
    }
    const blur = (): void => {
      touches.current.clear()
      pinch.current = null
      touchPan.current = null
      space.current = false
      finishKeyMove()
      finish(true)
    }
    const finishMove = (): void => finishKeyMove()
    const releasedOutside = (event: PointerEvent): void => {
      if (event.target instanceof Node && stage.current?.contains(event.target)) return
      endTouch(event.pointerId)
      if (drag.current?.pointerId === event.pointerId) finish(true)
    }
    const copy = (event: ClipboardEvent): boolean => {
      if (
        typing(event.target) ||
        drag.current ||
        window.document.querySelector(BOARD_DIALOG_SELECTOR) ||
        !event.clipboardData ||
        !store.getSnapshot().selected.size
      )
        return false
      finishKeyMove()
      const { document, selected } = store.getSnapshot()
      const elements = duplicateElements(document.elements, selected)
      event.clipboardData.setData('text/plain', JSON.stringify({ ...createDocument(), elements }))
      event.preventDefault()
      return true
    }
    const cut = (event: ClipboardEvent): void => {
      if (readOnly || !store.canRemoveSelection()) return
      if (copy(event)) store.removeSelected()
    }
    const paste = (event: ClipboardEvent): void => {
      if (readOnly) return
      if (typing(event.target) || drag.current || document.querySelector(BOARD_DIALOG_SELECTOR))
        return
      finishKeyMove()
      const files = Array.from(event.clipboardData?.files ?? [])
      if (files.length) {
        event.preventDefault()
        importImages(
          files,
          worldPoint(
            { x: stage.current!.clientWidth / 2, y: stage.current!.clientHeight / 2 },
            store.getSnapshot().camera,
          ),
        )
        return
      }
      const value = event.clipboardData?.getData('text/plain')
      if (!value) return
      event.preventDefault()
      pasteValue(value)
    }
    window.addEventListener('keydown', keydown)
    window.addEventListener('keyup', keyup)
    window.addEventListener('blur', blur)
    window.addEventListener('pointerdown', finishMove, true)
    window.addEventListener('focusin', finishMove)
    window.addEventListener('pointerup', releasedOutside)
    window.addEventListener('pointercancel', releasedOutside)
    window.addEventListener('copy', copy)
    window.addEventListener('cut', cut)
    window.addEventListener('paste', paste)
    return () => {
      window.removeEventListener('keydown', keydown)
      window.removeEventListener('keyup', keyup)
      window.removeEventListener('blur', blur)
      window.removeEventListener('pointerdown', finishMove, true)
      window.removeEventListener('focusin', finishMove)
      window.removeEventListener('pointerup', releasedOutside)
      window.removeEventListener('pointercancel', releasedOutside)
      window.removeEventListener('copy', copy)
      window.removeEventListener('cut', cut)
      window.removeEventListener('paste', paste)
    }
  })
  React.useEffect(
    () => () => {
      cancelAnimationFrame(frame.current)
      if (moveKeys.current.size) {
        moveKeys.current.clear()
        store.cancel()
      }
    },
    [store],
  )

  const endTouch = (id: number): boolean => {
    touches.current.delete(id)
    if (!pinch.current && !touchPan.current) return false
    const entries = [...touches.current]
    if (entries.length >= 2) {
      pinch.current = {
        camera: store.getSnapshot().camera,
        start: entries.slice(0, 2).map(([, point]) => point),
        ids: entries.slice(0, 2).map(([key]) => key),
      }
      touchPan.current = null
    } else {
      pinch.current = null
      touchPan.current = entries[0]
        ? { camera: store.getSnapshot().camera, id: entries[0][0], start: entries[0][1] }
        : null
    }
    suppressClick.current = performance.now() + 350
    return true
  }
  return {
    cancelInteraction(): void {
      finishKeyMove(true)
      finish(true)
      touches.current.clear()
      pinch.current = null
      touchPan.current = null
      closeContextMenu()
    },
    contextMenu,
    closeContextMenu,
    copyToClipboard,
    pasteFromClipboard,
    marquee,
    guides,
    rotationPreview,
    isInteracting,
    onClickCapture(event: React.MouseEvent<HTMLDivElement>): void {
      // React portal events still traverse the board component tree.
      if (event.target instanceof Node && !event.currentTarget.contains(event.target)) return
      if (performance.now() < suppressClick.current) {
        event.preventDefault()
        event.stopPropagation()
        return
      }
      if (
        event.detail > 0 &&
        event.target instanceof Element &&
        event.target.closest('.wb-card') &&
        !cardReceivesPointer(event)
      ) {
        event.preventDefault()
        event.stopPropagation()
      }
    },
    onContextMenu(event: React.MouseEvent<HTMLDivElement>): void {
      if (readOnly) return
      if (typing(event.target) || document.querySelector(BOARD_DIALOG_SELECTOR)) return
      event.preventDefault()
      finishKeyMove()
      finish(true)
      stage.current?.focus({ preventScroll: true })
      const snapshot = store.getSnapshot(),
        screen = local(event),
        point = worldPoint(screen, snapshot.camera)
      const targets = hitElements(
        snapshot.document.elements,
        point,
        6 / snapshot.camera.zoom,
        false,
        typography.labelBounds,
        { includeLocked: true, locked: snapshot.locked, hidden: snapshot.hidden },
      )
      if (targets[0] && !snapshot.selected.has(targets[0].id))
        store.select(new Set([targets[0].id]))
      setContextMenu({ ...screen, point, targets })
    },
    onDragOver(event: React.DragEvent<HTMLDivElement>): void {
      if (!event.dataTransfer.types.includes('Files')) return
      event.preventDefault()
      const transfer = event.dataTransfer
      transfer.dropEffect = 'copy'
    },
    onDrop(event: React.DragEvent<HTMLDivElement>): void {
      if (readOnly) {
        event.preventDefault()
        return
      }
      if (!event.dataTransfer.files.length) return
      event.preventDefault()
      if (drag.current || document.querySelector(BOARD_DIALOG_SELECTOR)) return
      finishKeyMove()
      importImages(
        Array.from(event.dataTransfer.files),
        worldPoint(local(event), store.getSnapshot().camera),
      )
    },
    onPointerDown(event: React.PointerEvent<HTMLDivElement>): void {
      if (document.querySelector(BOARD_DIALOG_SELECTOR)) return
      if (event.pointerType === 'touch' && !typing(event.target)) {
        touches.current.set(event.pointerId, local(event))
        if (touches.current.size >= 2) {
          finishKeyMove()
          finish(true)
          const entries = [...touches.current].slice(0, 2)
          pinch.current = {
            camera: store.getSnapshot().camera,
            start: entries.map(([, point]) => point),
            ids: entries.map(([id]) => id),
          }
          touchPan.current = null
          suppressClick.current = performance.now() + 350
          for (const id of touches.current.keys()) event.currentTarget.setPointerCapture(id)
          event.preventDefault()
          return
        }
      }
      if (
        (tool === 'select' || (readOnly && tool !== 'laser')) &&
        !space.current &&
        event.target instanceof Element &&
        event.target.closest('[data-card-content]') &&
        event.target.closest('a,button,summary,.cursor-pointer,.cursor-zoom-in') &&
        cardReceivesPointer(event)
      )
        return
      if ((event.button !== 0 && event.button !== 1) || typing(event.target)) return
      stage.current?.focus({ preventScroll: true })
      const screen = local(event),
        snapshot = store.getSnapshot(),
        point = worldPoint(screen, snapshot.camera)
      const active: IDrag = {
        pointerId: event.pointerId,
        kind: 'move',
        start: point,
        screen,
        camera: snapshot.camera,
        elements: snapshot.document.elements,
        selected: snapshot.selected,
        points: [point],
      }
      if (tool === 'laser') {
        active.kind = 'laser'
        laser(screen)
      } else if (readOnly || tool === 'hand' || space.current || event.button === 1)
        active.kind = 'pan'
      else if (tool === 'eraser') {
        active.kind = 'erase'
        active.erased = new Set()
        active.hitOptions = {
          includeLocked: true,
          map: new Map(active.elements.map(element => [element.id, element])),
          locked: snapshot.locked,
          hidden: snapshot.hidden,
          excluded: active.erased,
        }
        store.select(new Set())
      } else if (tool === 'select') {
        if (event.ctrlKey || event.metaKey) {
          const hits = hitElements(
            active.elements,
            point,
            6 / active.camera.zoom,
            false,
            typography.labelBounds,
            { locked: snapshot.locked, hidden: snapshot.hidden },
          )
          const seen = new Set<string>()
          const units = hits.filter(element => {
            const key = element.groupId ? `g:${element.groupId}` : `e:${element.id}`
            if (seen.has(key)) return false
            seen.add(key)
            return true
          })
          const index = units.findIndex(element => snapshot.selected.has(element.id))
          const next = units[(index + 1) % units.length]
          if (next) store.select(new Set([next.id]))
          event.preventDefault()
          return
        }
        const editable =
          store.canEditSelection() && [...snapshot.selected].some(id => !snapshot.hidden.has(id))
        const single =
          editable && snapshot.selected.size === 1
            ? snapshot.document.elements.find(item => snapshot.selected.has(item.id))
            : undefined
        const bounds = editable ? resizeBounds(snapshot.document.elements, snapshot.selected) : null
        const frame = editable ? transformBounds(active.elements, active.selected) : null
        const handle = frame ? rotationHandle(frame, active.camera.zoom) : undefined
        const rotating =
          handle && Math.hypot(point.x - handle.x, point.y - handle.y) <= 10 / active.camera.zoom
        const map = new Map(active.elements.map(element => [element.id, element]))
        const controlIndex =
          single?.type === 'edge'
            ? connectorControlAt(
                single,
                resolveEndpoint(single.from, map),
                resolveEndpoint(single.to, map),
                point,
                8 / snapshot.camera.zoom,
              )
            : -1
        const corner = bounds ? resizeCornerAt(bounds, point, 10 / snapshot.camera.zoom) : undefined
        const endpoint =
          single?.type === 'edge'
            ? edgeEndpointAt(single, point, map, 10 / snapshot.camera.zoom)
            : undefined
        if (rotating && frame) {
          active.kind = 'rotate'
          active.bounds = frame
          active.pivot = transformPivot(active.elements, active.selected, frame)
          active.startAngle = Math.atan2(point.y - active.pivot.y, point.x - active.pivot.x)
        } else if (single?.type === 'edge' && endpoint) {
          active.kind = 'reconnect'
          active.edge = single
          active.endpoint = endpoint
        } else if (single?.type === 'edge' && controlIndex >= 0) {
          if (event.altKey && single.routing === 'polyline') {
            const controls = connectorControls(
              single,
              resolveEndpoint(single.from, map),
              resolveEndpoint(single.to, map),
            ).filter((_, index) => index !== controlIndex)
            store.commit({
              ...snapshot.document,
              elements: active.elements.map(element =>
                element.id === single.id ? { ...single, controls } : element,
              ),
            })
            event.preventDefault()
            return
          }
          active.kind = 'control'
          active.edge = single
          active.controlIndex = controlIndex
        } else if (bounds && corner) {
          active.kind = 'resize'
          active.bounds = bounds
          active.corner = corner
        } else {
          const hit = hitTest(
            snapshot.document.elements,
            point,
            6 / snapshot.camera.zoom,
            false,
            typography.labelBounds,
          )
          const selected = new Set(
            event.shiftKey || (hit && snapshot.selected.has(hit.id)) ? snapshot.selected : [],
          )
          if (hit) {
            const members = expandSelection(snapshot.document.elements, new Set([hit.id]))
            const remove = event.shiftKey && selected.has(hit.id)
            for (const id of members) {
              if (remove) selected.delete(id)
              else selected.add(id)
            }
          } else {
            active.kind = 'marquee'
            setMarquee({ ...point, width: 1, height: 1 })
          }
          store.select(selected)
          active.selected = store.getSnapshot().selected
          if (hit && !store.canEditSelection()) {
            event.preventDefault()
            return
          }
        }
      } else {
        active.kind = 'draw'
        if (tool === 'edge') {
          const hit = hitTest(snapshot.document.elements, point, 12 / snapshot.camera.zoom, true)
          active.created = {
            id: crypto.randomUUID(),
            type: 'edge',
            style,
            ...edgeAppearance,
            from: attachEndpoint(hit?.type !== 'edge' ? hit : undefined, point),
            to: point,
          }
        } else active.created = createNode(tool, point, style)
        store.select(new Set([active.created.id]))
        store.preview([...active.elements, active.created])
      }
      if (active.kind === 'move') active.snap = prepareMoveSnap(active.elements, active.selected)
      drag.current = active
      if (active.kind === 'erase') update(screen, false, false)
      lastPointer.current = screen
      event.currentTarget.setPointerCapture(event.pointerId)
      event.preventDefault()
    },
    onPointerMove(event: React.PointerEvent<HTMLDivElement>): void {
      const screen = local(event)
      if (touches.current.has(event.pointerId)) touches.current.set(event.pointerId, screen)
      if (pinch.current) {
        const gesture = pinch.current
        const current = gesture.ids.map(id => touches.current.get(id)!)
        if (current.every(Boolean))
          store.camera(touchCamera(gesture.camera, gesture.start, current))
        suppressClick.current = performance.now() + 350
        event.preventDefault()
        return
      }
      if (touchPan.current) {
        const gesture = touchPan.current
        if (gesture.id === event.pointerId)
          store.camera({
            ...gesture.camera,
            x: gesture.camera.x + screen.x - gesture.start.x,
            y: gesture.camera.y + screen.y - gesture.start.y,
          })
        event.preventDefault()
        return
      }
      if (!drag.current || drag.current.pointerId !== event.pointerId) return
      scheduleUpdate(screen, event.shiftKey, event.altKey)
    },
    onPointerUp(event: React.PointerEvent<HTMLDivElement>): void {
      if (endTouch(event.pointerId)) return
      if (!drag.current || drag.current.pointerId !== event.pointerId) return
      pending.current = { point: local(event), shift: event.shiftKey, alt: event.altKey }
      finish()
      if (event.currentTarget.hasPointerCapture(event.pointerId))
        event.currentTarget.releasePointerCapture(event.pointerId)
    },
    onPointerCancel(event: React.PointerEvent<HTMLDivElement>): void {
      if (!endTouch(event.pointerId) && drag.current?.pointerId === event.pointerId) finish(true)
    },
    onLostPointerCapture(event: React.PointerEvent<HTMLDivElement>): void {
      if (!endTouch(event.pointerId) && drag.current?.pointerId === event.pointerId) finish(true)
    },
    onDoubleClick(event: React.MouseEvent<HTMLDivElement>): void {
      if (readOnly || tool !== 'select') return
      const snapshot = store.getSnapshot()
      const node = hitTest(
        snapshot.document.elements,
        worldPoint(local(event), snapshot.camera),
        6 / snapshot.camera.zoom,
        false,
        typography.labelBounds,
      )
      if (node && node.type !== 'stroke') edit(node)
    },
  }
}
