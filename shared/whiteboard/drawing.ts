import { boundsBetween, unionBounds } from './geometry.ts'
import type { IBounds, IElement, IPoint } from './model.ts'
import { nodeBounds } from './pose.ts'

export function drawingBounds(
  start: IPoint,
  point: IPoint,
  square: boolean,
  centered: boolean,
): IBounds {
  let dx = point.x - start.x,
    dy = point.y - start.y
  if (square) {
    const size = Math.max(1, Math.abs(dx), Math.abs(dy))
    dx = (dx < 0 ? -1 : 1) * size
    dy = (dy < 0 ? -1 : 1) * size
  }
  return boundsBetween(centered ? { x: start.x - dx, y: start.y - dy } : start, {
    x: start.x + dx,
    y: start.y + dy,
  })
}

export function constrainAngle(start: IPoint, point: IPoint): IPoint {
  const dx = point.x - start.x,
    dy = point.y - start.y
  const angle = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4)
  const length = Math.hypot(dx, dy)
  return { x: start.x + Math.cos(angle) * length, y: start.y + Math.sin(angle) * length }
}

export interface IAlignmentGuide {
  readonly axis: 'x' | 'y'
  readonly position: number
  readonly from: number
  readonly to: number
}

export interface IMoveSnap {
  readonly bounds: IBounds
  readonly targets: ReadonlyArray<IBounds>
}

// Build targets once per gesture. Edges and freehand paths have no useful layout anchors.
export function prepareMoveSnap(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): IMoveSnap | null {
  const nodes = elements.filter(element => element.type !== 'edge' && element.type !== 'stroke')
  const bounds = unionBounds(nodes.filter(element => selected.has(element.id)).map(nodeBounds))
  return bounds
    ? {
        bounds,
        targets: nodes
          .filter(element => !selected.has(element.id) && !element.hidden)
          .map(nodeBounds),
      }
    : null
}

export function snapMove(
  snap: IMoveSnap,
  delta: IPoint,
  tolerance: number,
): { delta: IPoint; guides: IAlignmentGuide[] } {
  const moved = { ...snap.bounds, x: snap.bounds.x + delta.x, y: snap.bounds.y + delta.y }
  const result = { ...delta }
  const guides: IAlignmentGuide[] = []
  for (const axis of ['x', 'y'] as const) {
    const size = axis === 'x' ? 'width' : 'height'
    const cross = axis === 'x' ? 'y' : 'x'
    const crossSize = axis === 'x' ? 'height' : 'width'
    let best: { offset: number; distance: number; target: IBounds; position: number } | undefined
    for (const target of snap.targets) {
      // Avoid attracting a block to a distant, unrelated row or column.
      const gap = Math.max(
        target[cross] - moved[cross] - moved[crossSize],
        moved[cross] - target[cross] - target[crossSize],
        0,
      )
      if (gap > Math.max(moved[crossSize], target[crossSize]) + tolerance * 8) continue
      for (const origin of [0, 0.5, 1]) {
        for (const destination of [0, 0.5, 1]) {
          const position = target[axis] + target[size] * destination
          const offset = position - moved[axis] - moved[size] * origin
          const distance = Math.abs(offset)
          if (distance <= tolerance && (!best || distance < best.distance))
            best = { offset, distance, target, position }
        }
      }
    }
    if (best) {
      result[axis] += best.offset
      guides.push({
        axis,
        position: best.position,
        from: Math.min(moved[cross], best.target[cross]),
        to: Math.max(moved[cross] + moved[crossSize], best.target[cross] + best.target[crossSize]),
      })
    }
  }
  return { delta: result, guides }
}
