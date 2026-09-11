import { unionBounds } from './geometry.ts'
import type { IBounds, IElement, IEndpoint, IPoint } from './model.ts'

export const RESIZE_CORNERS: ReadonlyArray<IPoint> = [
  { x: 0, y: 0 },
  { x: 1, y: 0 },
  { x: 0, y: 1 },
  { x: 1, y: 1 },
]

// Selection is already expanded to whole groups by BoardStore.
export function resizeBounds(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): IBounds | null {
  const bounds: IBounds[] = []
  let nodes = 0
  for (const element of elements) {
    if (!selected.has(element.id)) continue
    if (element.type !== 'edge') {
      bounds.push(element)
      nodes += 1
    } else {
      for (const endpoint of [element.from, element.to]) {
        if (!endpoint.nodeId) bounds.push({ ...endpoint, width: 0, height: 0 })
      }
    }
  }
  return nodes ? unionBounds(bounds) : null
}

export function resizeCornerAt(
  bounds: IBounds,
  point: IPoint,
  tolerance: number,
): IPoint | undefined {
  let nearest: IPoint | undefined
  let distance = tolerance
  for (const corner of RESIZE_CORNERS) {
    const current = Math.hypot(
      point.x - bounds.x - corner.x * bounds.width,
      point.y - bounds.y - corner.y * bounds.height,
    )
    if (current <= distance) {
      distance = current
      nearest = corner
    }
  }
  return nearest
}

export function resizeElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  bounds: IBounds,
  corner: IPoint,
  point: IPoint,
  preserveAspect: boolean,
): ReadonlyArray<IElement> {
  const anchor = {
    x: bounds.x + (1 - corner.x) * bounds.width,
    y: bounds.y + (1 - corner.y) * bounds.height,
  }
  let scaleX = ((point.x - anchor.x) * (corner.x ? 1 : -1)) / bounds.width
  let scaleY = ((point.y - anchor.y) * (corner.y ? 1 : -1)) / bounds.height
  let minX = 0,
    minY = 0
  for (const element of elements) {
    if (!selected.has(element.id) || element.type === 'edge') continue
    minX = Math.max(minX, Math.min(16, element.width) / element.width)
    minY = Math.max(minY, Math.min(16, element.height) / element.height)
  }
  if (preserveAspect) {
    const scale = Math.abs(scaleX - 1) > Math.abs(scaleY - 1) ? scaleX : scaleY
    scaleX = scaleY = Math.max(minX, minY, scale)
  } else {
    scaleX = Math.max(minX, scaleX)
    scaleY = Math.max(minY, scaleY)
  }
  if (scaleX === 1 && scaleY === 1) return elements
  const transform = (point: IPoint): IPoint => ({
    x: anchor.x + (point.x - anchor.x) * scaleX,
    y: anchor.y + (point.y - anchor.y) * scaleY,
  })
  const endpoint = (point: IEndpoint): IEndpoint => (point.nodeId ? point : transform(point))
  return elements.map(element => {
    if (!selected.has(element.id)) return element
    return element.type === 'edge'
      ? { ...element, from: endpoint(element.from), to: endpoint(element.to) }
      : {
          ...element,
          ...transform(element),
          width: element.width * scaleX,
          height: element.height * scaleY,
        }
  })
}
