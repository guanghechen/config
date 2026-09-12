import React from 'react'
import { updateGesture } from './gestures'
import type { IDrag } from './gestures'
import { boardKeyboard } from './keyboard'
import { useBoardClipboard } from './clipboard'
import { hasBoardDialog, typing } from './targets'
import { createNode } from './createNode'
import {
  attachEndpoint,
  edgeEndpointAt,
  elementBounds,
  hitElements,
  hitTest,
  intersects,
  resolveEndpoint,
  worldPoint,
  zoomAt,
} from '@/shared/whiteboard/geometry'

import { expandSelection } from '@/shared/whiteboard/organization'
import {
  resizeBounds,
  resizeCornerAt,
  transformBounds,
  transformPivot,
} from '@/shared/whiteboard/transforms'
import { rotationHandle } from '@/shared/whiteboard/pose'
import type { ITransformFrame } from '@/shared/whiteboard/pose'
import { connectorControlAt, connectorControls } from '@/shared/whiteboard/edges'
import { drawingBounds, prepareMoveSnap } from '@/shared/whiteboard/drawing'
import type { IAlignmentGuide } from '@/shared/whiteboard/drawing'
import type {
  IBounds,
  ICamera,
  IEdgeAppearance,
  IElement,
  IPoint,
  IStyle,
} from '@/shared/whiteboard/model'
import type { BoardStore } from '../store'

import { touchCamera } from '@/shared/whiteboard/navigation'

import type { BoardTypography } from '../rendering/typography'

import type { ITool } from './tools'

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

  const { copyToClipboard, pasteFromClipboard } = useBoardClipboard({
    stage,
    store,
    style,
    readOnly,
    isInteracting,
    isDragging: () => !!drag.current,
    finishKeyMove,
    importImages,
    message,
  })
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

  const update = (screen: IPoint, preserveAspect: boolean, alt: boolean): void => {
    updateGesture(screen, preserveAspect, alt, {
      drag,
      store,
      typography,
      laser,
      setRotationPreview,
      setGuides,
      setMarquee: bounds => {
        marqueeRef.current = bounds
        setMarquee(bounds)
      },
    })
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
    const { keydown, keyup } = boardKeyboard({
      stage,
      store,
      readOnly,
      isDragging: () => !!drag.current,
      isTouchGesture: () => !!pinch.current || !!touchPan.current,
      lastPointer,
      moveKeys,
      setSpace: value => {
        space.current = value
      },
      scheduleUpdate,
      finishKeyMove,
      finish,
      setTool,
      edit,
      toggleLock,
    })
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
    window.addEventListener('keydown', keydown)
    window.addEventListener('keyup', keyup)
    window.addEventListener('blur', blur)
    window.addEventListener('pointerdown', finishMove, true)
    window.addEventListener('focusin', finishMove)
    window.addEventListener('pointerup', releasedOutside)
    window.addEventListener('pointercancel', releasedOutside)
    return () => {
      window.removeEventListener('keydown', keydown)
      window.removeEventListener('keyup', keyup)
      window.removeEventListener('blur', blur)
      window.removeEventListener('pointerdown', finishMove, true)
      window.removeEventListener('focusin', finishMove)
      window.removeEventListener('pointerup', releasedOutside)
      window.removeEventListener('pointercancel', releasedOutside)
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
      if (typing(event.target) || hasBoardDialog(stage.current)) return
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
      if (drag.current || hasBoardDialog(stage.current)) return
      finishKeyMove()
      importImages(
        Array.from(event.dataTransfer.files),
        worldPoint(local(event), store.getSnapshot().camera),
      )
    },
    onPointerDown(event: React.PointerEvent<HTMLDivElement>): void {
      if (hasBoardDialog(stage.current)) return
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
