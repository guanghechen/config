import type React from 'react'
import {
  attachEndpoint,
  boundsBetween,
  hitTest,
  moveElements,
  reconnectEdge,
  resolveEndpoint,
  worldPoint,
} from '@/shared/whiteboard/geometry'
import type { IHitTestOptions } from '@/shared/whiteboard/geometry'
import { constrainAngle, drawingBounds, snapMove } from '@/shared/whiteboard/drawing'
import type { IAlignmentGuide, IMoveSnap } from '@/shared/whiteboard/drawing'
import { resizeElements, rotateElements } from '@/shared/whiteboard/transforms'
import { framePoint, rotatePoint } from '@/shared/whiteboard/pose'
import type { ITransformFrame } from '@/shared/whiteboard/pose'
import { connectorControls } from '@/shared/whiteboard/edges'
import { eraseAlong } from '@/shared/whiteboard/erasing'
import { removeElements } from '@/shared/whiteboard/commands'
import type { IBounds, ICamera, IEdge, IElement, IPoint } from '@/shared/whiteboard/model'
import type { BoardStore } from '../store'
import type { BoardTypography } from '../rendering/typography'

export interface IDrag {
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

// The input coordinator owns this transient gesture; previews remain one store transaction.
export function updateGesture(
  screen: IPoint,
  preserveAspect: boolean,
  alt: boolean,
  {
    drag,
    store,
    typography,
    laser,
    setRotationPreview,
    setGuides,
    setMarquee,
  }: {
    drag: React.RefObject<IDrag | null>
    store: BoardStore
    typography: BoardTypography
    laser: (point: IPoint) => void
    setRotationPreview: (bounds: ITransformFrame) => void
    setGuides: (guides: ReadonlyArray<IAlignmentGuide>) => void
    setMarquee: (bounds: IBounds) => void
  },
) {
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
      ((Math.atan2(point.y - active.pivot.y, point.x - active.pivot.x) - active.startAngle) * 180) /
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
    setMarquee(boundsBetween(active.start, point))
  } else if (active.created) {
    let created = active.created
    if (created.type === 'edge') {
      const hit = hitTest(active.elements, point, 12 / active.camera.zoom, true)
      created = {
        ...created,
        to: preserveAspect
          ? constrainAngle(
              resolveEndpoint(created.from, new Map(active.elements.map(item => [item.id, item]))),
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
