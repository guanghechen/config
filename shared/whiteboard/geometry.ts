import type {
  IBounds,
  ICamera,
  IEdge,
  IElement,
  IEndpoint,
  ILabelElement,
  INode,
  IPoint,
} from './model.ts'
import { wrapLabel } from './labels.ts'

export function worldPoint(point: IPoint, camera: ICamera): IPoint {
  return { x: (point.x - camera.x) / camera.zoom, y: (point.y - camera.y) / camera.zoom }
}

export function zoomAt(camera: ICamera, point: IPoint, zoom: number): ICamera {
  const nextZoom = Math.min(8, Math.max(0.05, zoom))
  const world = worldPoint(point, camera)
  return { x: point.x - world.x * nextZoom, y: point.y - world.y * nextZoom, zoom: nextZoom }
}

export function boundsBetween(a: IPoint, b: IPoint): IBounds {
  return {
    x: Math.min(a.x, b.x),
    y: Math.min(a.y, b.y),
    width: Math.max(1, Math.abs(b.x - a.x)),
    height: Math.max(1, Math.abs(b.y - a.y)),
  }
}

export function intersects(a: IBounds, b: IBounds): boolean {
  return (
    a.x <= b.x + b.width && a.x + a.width >= b.x && a.y <= b.y + b.height && a.y + a.height >= b.y
  )
}

export function resolveEndpoint(endpoint: IEndpoint, nodes: ReadonlyMap<string, IElement>): IPoint {
  const node = endpoint.nodeId ? nodes.get(endpoint.nodeId) : undefined
  if (!node || node.type === 'edge') return endpoint
  return { x: node.x + endpoint.x * node.width, y: node.y + endpoint.y * node.height }
}

export function attachEndpoint(node: INode | undefined, point: IPoint): IEndpoint {
  if (!node) return point
  let x = Math.min(1, Math.max(0, (point.x - node.x) / node.width))
  let y = Math.min(1, Math.max(0, (point.y - node.y) / node.height))
  const distances = [x * node.width, (1 - x) * node.width, y * node.height, (1 - y) * node.height]
  const side = distances.indexOf(Math.min(...distances))
  if (side === 0) x = 0
  else if (side === 1) x = 1
  else if (side === 2) y = 0
  else y = 1
  if (node.type === 'shape' && (node.shape === 'ellipse' || node.shape === 'diamond')) {
    const dx = (point.x - node.x) / node.width - 0.5
    const dy = (point.y - node.y) / node.height - 0.5
    const scale = node.shape === 'ellipse' ? Math.hypot(dx, dy) : Math.abs(dx) + Math.abs(dy)
    x = scale ? 0.5 + dx / (scale * 2) : 1
    y = scale ? 0.5 + dy / (scale * 2) : 0.5
  }
  return { nodeId: node.id, x, y }
}

export function elementBounds(element: IElement, nodes: ReadonlyMap<string, IElement>): IBounds {
  if (element.type !== 'edge') return element
  const bounds = boundsBetween(
    resolveEndpoint(element.from, nodes),
    resolveEndpoint(element.to, nodes),
  )
  // A conservative label envelope avoids measuring text in the per-frame culling path.
  return element.label ? unionBounds([bounds, labelArea(element, nodes)])! : bounds
}

export function labelArea(element: ILabelElement, nodes: ReadonlyMap<string, IElement>): IBounds {
  if (element.type === 'edge') {
    const from = resolveEndpoint(element.from, nodes),
      to = resolveEndpoint(element.to, nodes)
    return { x: (from.x + to.x) / 2 - 118, y: (from.y + to.y) / 2 - 45, width: 236, height: 90 }
  }
  const scale = element.shape === 'diamond' ? 0.5 : element.shape === 'ellipse' ? Math.SQRT1_2 : 1
  const width = Math.max(1, element.width * scale - 24),
    height = Math.max(1, element.height * scale - 24)
  return {
    x: element.x + (element.width - width) / 2,
    y: element.y + (element.height - height) / 2,
    width,
    height,
  }
}

export function labelLayout(element: ILabelElement, nodes: ReadonlyMap<string, IElement>) {
  const area = labelArea(element, nodes)
  const padding = element.type === 'edge' ? 8 : 0
  const layout = wrapLabel(element.label ?? '', area.width - padding * 2, area.height - padding * 2)
  return {
    ...layout,
    bounds: {
      x: area.x + (area.width - layout.width) / 2 - padding,
      y: area.y + (area.height - layout.height) / 2 - padding,
      width: layout.width + padding * 2,
      height: layout.height + padding * 2,
    },
  }
}

export function edgeEndpointAt(
  edge: IEdge,
  point: IPoint,
  nodes: ReadonlyMap<string, IElement>,
  tolerance: number,
): 'from' | 'to' | undefined {
  for (const end of ['from', 'to'] as const) {
    const position = resolveEndpoint(edge[end], nodes)
    if (Math.hypot(position.x - point.x, position.y - point.y) <= tolerance) return end
  }
  return undefined
}

export function reconnectEdge(
  edge: IEdge,
  end: 'from' | 'to',
  point: IPoint,
  elements: ReadonlyArray<IElement>,
  tolerance: number,
): IEdge {
  const hit = hitTest(elements, point, tolerance, true)
  return { ...edge, [end]: attachEndpoint(hit?.type !== 'edge' ? hit : undefined, point) }
}

export function unionBounds(bounds: ReadonlyArray<IBounds>): IBounds | null {
  if (!bounds.length) return null
  let x = Infinity,
    y = Infinity,
    right = -Infinity,
    bottom = -Infinity
  for (const item of bounds) {
    x = Math.min(x, item.x)
    y = Math.min(y, item.y)
    right = Math.max(right, item.x + item.width)
    bottom = Math.max(bottom, item.y + item.height)
  }
  return { x, y, width: Math.max(1, right - x), height: Math.max(1, bottom - y) }
}

export function segmentDistance(point: IPoint, a: IPoint, b: IPoint): number {
  const dx = b.x - a.x,
    dy = b.y - a.y
  const t = Math.max(
    0,
    Math.min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy || 1)),
  )
  return Math.hypot(point.x - a.x - t * dx, point.y - a.y - t * dy)
}

function quadraticHit(
  point: IPoint,
  a: IPoint,
  control: IPoint,
  b: IPoint,
  tolerance: number,
  depth = 0,
): boolean {
  if (
    point.x < Math.min(a.x, control.x, b.x) - tolerance ||
    point.x > Math.max(a.x, control.x, b.x) + tolerance ||
    point.y < Math.min(a.y, control.y, b.y) - tolerance ||
    point.y > Math.max(a.y, control.y, b.y) + tolerance
  )
    return false
  if (depth === 16 || segmentDistance(control, a, b) <= tolerance / 2)
    return segmentDistance(point, a, b) <= tolerance
  const left = { x: (a.x + control.x) / 2, y: (a.y + control.y) / 2 }
  const right = { x: (control.x + b.x) / 2, y: (control.y + b.y) / 2 }
  const middle = { x: (left.x + right.x) / 2, y: (left.y + right.y) / 2 }
  return (
    quadraticHit(point, a, left, middle, tolerance, depth + 1) ||
    quadraticHit(point, middle, right, b, tolerance, depth + 1)
  )
}

export function hitTest(
  elements: ReadonlyArray<IElement>,
  point: IPoint,
  tolerance: number,
  nodesOnly = false,
): IElement | undefined {
  const map = new Map(elements.map(element => [element.id, element]))
  // Card layer is above drawings, which are above edges.
  for (const layer of [2, 1, 0]) {
    for (let i = elements.length - 1; i >= 0; i--) {
      const element = elements[i]
      const current =
        element.type === 'edge' ? 0 : ['markdown', 'image'].includes(element.type) ? 2 : 1
      if (current !== layer || (nodesOnly && element.type === 'edge')) continue
      if (element.type === 'edge') {
        if (
          element.label &&
          intersects(labelArea(element, map), { ...point, width: 0, height: 0 }) &&
          intersects(labelLayout(element, map).bounds, {
            x: point.x - tolerance,
            y: point.y - tolerance,
            width: tolerance * 2,
            height: tolerance * 2,
          })
        )
          return element
        if (
          segmentDistance(
            point,
            resolveEndpoint(element.from, map),
            resolveEndpoint(element.to, map),
          ) <= tolerance
        )
          return element
        continue
      }
      if (
        !intersects(element, {
          x: point.x - tolerance,
          y: point.y - tolerance,
          width: tolerance * 2,
          height: tolerance * 2,
        })
      )
        continue
      if (element.type === 'stroke') {
        if (nodesOnly) continue
        const points = element.points.map(p => ({
          x: element.x + p.x * element.width,
          y: element.y + p.y * element.height,
        }))
        let start = points[0]
        for (let index = 1; index < points.length - 1; index++) {
          const control = points[index],
            next = points[index + 1]
          const end = { x: (control.x + next.x) / 2, y: (control.y + next.y) / 2 }
          if (quadraticHit(point, start, control, end, tolerance)) return element
          start = end
        }
        if (segmentDistance(point, start, points[points.length - 1]) <= tolerance) return element
        continue
      }
      const dx = (point.x - element.x - element.width / 2) / (element.width / 2 + tolerance)
      const dy = (point.y - element.y - element.height / 2) / (element.height / 2 + tolerance)
      if (element.type === 'shape' && element.shape === 'ellipse' && dx * dx + dy * dy > 1) continue
      if (
        element.type === 'shape' &&
        element.shape === 'diamond' &&
        Math.abs(dx) + Math.abs(dy) > 1
      )
        continue
      return element
    }
  }
  return undefined
}

export function moveElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  delta: IPoint,
): IElement[] {
  const move = (p: IEndpoint): IEndpoint => (p.nodeId ? p : { x: p.x + delta.x, y: p.y + delta.y })
  return elements.map(element => {
    if (!selected.has(element.id)) return element
    return element.type === 'edge'
      ? { ...element, from: move(element.from), to: move(element.to) }
      : { ...element, x: element.x + delta.x, y: element.y + delta.y }
  })
}

export function duplicateElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): IElement[] {
  const originals = elements.filter(element => selected.has(element.id))
  const ids = new Map(originals.map(element => [element.id, crypto.randomUUID()]))
  const groups = new Map<string, string>()
  for (const element of originals) {
    if (element.groupId && !groups.has(element.groupId))
      groups.set(element.groupId, crypto.randomUUID())
  }
  const map = new Map(elements.map(element => [element.id, element]))
  const endpoint = (p: IEndpoint): IEndpoint => {
    if (p.nodeId && ids.has(p.nodeId)) return { ...p, nodeId: ids.get(p.nodeId) }
    const point = resolveEndpoint(p, map)
    return { x: point.x + 24, y: point.y + 24 }
  }
  return originals.map(element =>
    element.type === 'edge'
      ? {
          ...element,
          id: ids.get(element.id)!,
          ...(element.groupId ? { groupId: groups.get(element.groupId)! } : {}),
          from: endpoint(element.from),
          to: endpoint(element.to),
        }
      : {
          ...element,
          id: ids.get(element.id)!,
          ...(element.groupId ? { groupId: groups.get(element.groupId)! } : {}),
          x: element.x + 24,
          y: element.y + 24,
        },
  )
}
