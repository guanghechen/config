import React from 'react'
import {
  attachEndpoint,
  boundsBetween,
  duplicateElements,
  edgeEndpointAt,
  elementBounds,
  hitTest,
  intersects,
  moveElements,
  reconnectEdge,
  resolveEndpoint,
  worldPoint,
  zoomAt,
} from '@/shared/whiteboard/geometry'
import { parseDocument } from '@/shared/whiteboard/document'
import { createDocument } from '@/shared/whiteboard/model'
import { expandSelection } from '@/shared/whiteboard/organization'
import { resizeBounds, resizeCornerAt, resizeElements } from '@/shared/whiteboard/transforms'
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
  IElement,
  INode,
  IPoint,
  IStyle,
} from '@/shared/whiteboard/model'
import type { BoardStore } from './store'
import { TOOLS } from './tools'
import type { ITool } from './tools'

interface IDrag {
  kind: 'pan' | 'move' | 'resize' | 'reconnect' | 'marquee' | 'draw'
  start: IPoint
  screen: IPoint
  camera: ICamera
  elements: ReadonlyArray<IElement>
  selected: ReadonlySet<string>
  bounds?: IBounds
  edge?: IEdge
  endpoint?: 'from' | 'to'
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
  if (tool === 'text') return { ...base, type: 'text', width: 260, height: 100, text: 'Your idea' }
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

const typing = (target: EventTarget | null): boolean =>
  target instanceof Element &&
  !!target.closest(
    'input,textarea,select,dialog,[contenteditable="true"],.monaco-editor,[role="dialog"]',
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
) {
  const [marquee, setMarquee] = React.useState<IBounds>()
  const [guides, setGuides] = React.useState<ReadonlyArray<IAlignmentGuide>>([])
  const marqueeRef = React.useRef<IBounds | undefined>(undefined)
  const drag = React.useRef<IDrag | null>(null)
  const space = React.useRef(false)
  const frame = React.useRef(0)
  const pending = React.useRef<{ point: IPoint; shift: boolean; alt: boolean } | null>(null)
  const lastPointer = React.useRef<IPoint | null>(null)
  const moveKeys = React.useRef(new Set<string>())
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

  const update = (screen: IPoint, preserveAspect: boolean, alt: boolean): void => {
    const active = drag.current
    if (!active) return
    const point = worldPoint(screen, active.camera)
    if (active.kind === 'pan') {
      store.camera({
        ...active.camera,
        x: active.camera.x + screen.x - active.screen.x,
        y: active.camera.y + screen.y - active.screen.y,
      })
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
    } else if (active.kind === 'resize' && active.bounds && active.corner) {
      store.preview(
        resizeElements(
          active.elements,
          active.selected,
          active.bounds,
          active.corner,
          {
            x: active.bounds.x + active.corner.x * active.bounds.width + point.x - active.start.x,
            y: active.bounds.y + active.corner.y * active.bounds.height + point.y - active.start.y,
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
    if (cancel) store.cancel()
    else if (active.kind === 'marquee') {
      const selected = new Set(active.selected)
      const map = new Map(active.elements.map(item => [item.id, item]))
      if (marqueeRef.current)
        for (const item of active.elements)
          if (intersects(elementBounds(item, map), marqueeRef.current)) selected.add(item.id)
      store.select(selected)
    } else if (active.kind !== 'pan') {
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
        store.getSnapshot().selected.has(card.dataset.nodeId!) &&
        !event.ctrlKey &&
        !event.metaKey &&
        !event.shiftKey &&
        (event.target as Element).closest('[data-card-content]')
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
  }, [stage, store, local])

  React.useEffect(() => {
    const keydown = (event: KeyboardEvent): void => {
      if (
        typing(event.target) ||
        document.querySelector('.wb-editor,.wb-label-editor,.wb-reference')
      )
        return
      const command = event.ctrlKey || event.metaKey
      const key = event.key.toLowerCase()
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
        store.select(new Set(snapshot.document.elements.map(item => item.id)))
        return
      }
      if (command && key === 'd') {
        event.preventDefault()
        const copies = duplicateElements(snapshot.document.elements, snapshot.selected)
        store.commit({ ...snapshot.document, elements: [...snapshot.document.elements, ...copies] })
        store.select(new Set(copies.map(item => item.id)))
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
      space.current = false
      finishKeyMove()
      finish(true)
    }
    const finishMove = (): void => finishKeyMove()
    const copy = (event: ClipboardEvent): void => {
      if (typing(event.target) || !store.getSnapshot().selected.size) return
      finishKeyMove()
      const { document, selected } = store.getSnapshot()
      const elements = duplicateElements(document.elements, selected)
      event.clipboardData?.setData('text/plain', JSON.stringify({ ...createDocument(), elements }))
      event.preventDefault()
    }
    const paste = (event: ClipboardEvent): void => {
      if (typing(event.target)) return
      finishKeyMove()
      const value = event.clipboardData?.getData('text/plain')
      if (!value) return
      event.preventDefault()
      try {
        const document = store.getSnapshot().document
        let elements: ReadonlyArray<IElement>
        if (value.trim().startsWith('{') && value.includes('yoz.whiteboard')) {
          const pasted = parseDocument(value)
          elements = duplicateElements(
            pasted.elements,
            new Set(pasted.elements.map(item => item.id)),
          )
        } else {
          const camera = store.getSnapshot().camera
          const point = worldPoint(
            { x: stage.current!.clientWidth / 2, y: stage.current!.clientHeight / 2 },
            camera,
          )
          elements = [
            {
              ...createNode('markdown', point, style),
              type: 'markdown',
              source: { kind: 'inline', content: value },
            },
          ]
        }
        store.commit({ ...document, elements: [...document.elements, ...elements] })
        store.select(new Set(elements.map(item => item.id)))
      } catch (error) {
        message(error instanceof Error ? error.message : String(error))
      }
    }
    window.addEventListener('keydown', keydown)
    window.addEventListener('keyup', keyup)
    window.addEventListener('blur', blur)
    window.addEventListener('pointerdown', finishMove, true)
    window.addEventListener('focusin', finishMove)
    window.addEventListener('copy', copy)
    window.addEventListener('paste', paste)
    return () => {
      window.removeEventListener('keydown', keydown)
      window.removeEventListener('keyup', keyup)
      window.removeEventListener('blur', blur)
      window.removeEventListener('pointerdown', finishMove, true)
      window.removeEventListener('focusin', finishMove)
      window.removeEventListener('copy', copy)
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

  return {
    marquee,
    guides,
    onPointerDown(event: React.PointerEvent<HTMLDivElement>): void {
      if (document.querySelector('.wb-editor,.wb-reference,.wb-label-editor')) return
      if (
        tool === 'select' &&
        !space.current &&
        event.target instanceof Element &&
        event.target.closest('[data-card-content]') &&
        event.target.closest('a,button,summary,.cursor-pointer')
      )
        return
      if ((event.button !== 0 && event.button !== 1) || typing(event.target)) return
      stage.current?.focus({ preventScroll: true })
      const screen = local(event),
        snapshot = store.getSnapshot(),
        point = worldPoint(screen, snapshot.camera)
      const active: IDrag = {
        kind: 'move',
        start: point,
        screen,
        camera: snapshot.camera,
        elements: snapshot.document.elements,
        selected: snapshot.selected,
        points: [point],
      }
      if (tool === 'hand' || space.current || event.button === 1) active.kind = 'pan'
      else if (tool === 'select') {
        const single =
          snapshot.selected.size === 1
            ? snapshot.document.elements.find(item => snapshot.selected.has(item.id))
            : undefined
        const bounds = resizeBounds(snapshot.document.elements, snapshot.selected)
        const corner = bounds ? resizeCornerAt(bounds, point, 10 / snapshot.camera.zoom) : undefined
        const endpoint =
          single?.type === 'edge'
            ? edgeEndpointAt(
                single,
                point,
                new Map(active.elements.map(element => [element.id, element])),
                10 / snapshot.camera.zoom,
              )
            : undefined
        if (single?.type === 'edge' && endpoint) {
          active.kind = 'reconnect'
          active.edge = single
          active.endpoint = endpoint
        } else if (bounds && corner) {
          active.kind = 'resize'
          active.bounds = bounds
          active.corner = corner
        } else {
          const hit = hitTest(snapshot.document.elements, point, 6 / snapshot.camera.zoom)
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
        }
      } else {
        active.kind = 'draw'
        if (tool === 'edge') {
          const hit = hitTest(snapshot.document.elements, point, 12 / snapshot.camera.zoom, true)
          active.created = {
            id: crypto.randomUUID(),
            type: 'edge',
            style,
            from: attachEndpoint(hit?.type !== 'edge' ? hit : undefined, point),
            to: point,
          }
        } else active.created = createNode(tool, point, style)
        store.select(new Set([active.created.id]))
        store.preview([...active.elements, active.created])
      }
      if (active.kind === 'move') active.snap = prepareMoveSnap(active.elements, active.selected)
      drag.current = active
      lastPointer.current = screen
      event.currentTarget.setPointerCapture(event.pointerId)
      event.preventDefault()
    },
    onPointerMove(event: React.PointerEvent<HTMLDivElement>): void {
      if (!drag.current) return
      scheduleUpdate(local(event), event.shiftKey, event.altKey)
    },
    onPointerUp(event: React.PointerEvent<HTMLDivElement>): void {
      if (!drag.current) return
      pending.current = { point: local(event), shift: event.shiftKey, alt: event.altKey }
      finish()
      if (event.currentTarget.hasPointerCapture(event.pointerId))
        event.currentTarget.releasePointerCapture(event.pointerId)
    },
    onPointerCancel(): void {
      finish(true)
    },
    onDoubleClick(event: React.MouseEvent<HTMLDivElement>): void {
      if (tool !== 'select') return
      const snapshot = store.getSnapshot()
      const node = hitTest(
        snapshot.document.elements,
        worldPoint(local(event), snapshot.camera),
        6 / snapshot.camera.zoom,
        false,
      )
      if (node && node.type !== 'stroke') edit(node)
    },
  }
}
