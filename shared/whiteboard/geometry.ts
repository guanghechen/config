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
import { quadraticHit, segmentDistance } from './curves.ts'
import { connectorBounds, connectorHit, connectorMidpoint, connectorPath } from './edges.ts'
import { textSize } from './text.ts'
import type { ITextLayout } from './text.ts'
import { nodeBounds, nodeLocalPoint, nodePoint } from './pose.ts'
import { hiddenElements, lockedElements } from './visibility.ts'
export { segmentDistance } from './curves.ts'

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
  return nodePoint(node, { x: endpoint.x * node.width, y: endpoint.y * node.height })
}

export function attachEndpoint(node: INode | undefined, point: IPoint): IEndpoint {
  if (!node) return point
  const local = nodeLocalPoint(node, point)
  let x = Math.min(1, Math.max(0, local.x / node.width))
  let y = Math.min(1, Math.max(0, local.y / node.height))
  const distances = [x * node.width, (1 - x) * node.width, y * node.height, (1 - y) * node.height]
  const side = distances.indexOf(Math.min(...distances))
  if (side === 0) x = 0
  else if (side === 1) x = 1
  else if (side === 2) y = 0
  else y = 1
  if (node.type === 'shape' && (node.shape === 'ellipse' || node.shape === 'diamond')) {
    const dx = local.x / node.width - 0.5
    const dy = local.y / node.height - 0.5
    const scale = node.shape === 'ellipse' ? Math.hypot(dx, dy) : Math.abs(dx) + Math.abs(dy)
    x = scale ? 0.5 + dx / (scale * 2) : 1
    y = scale ? 0.5 + dy / (scale * 2) : 0.5
  }
  return { nodeId: node.id, x, y }
}

export function elementBounds(element: IElement, nodes: ReadonlyMap<string, IElement>): IBounds {
  if (element.type !== 'edge') return nodeBounds(element)
  const bounds = connectorBounds(
    connectorPath(
      element,
      resolveEndpoint(element.from, nodes),
      resolveEndpoint(element.to, nodes),
    ),
  )
  // A conservative label envelope avoids measuring text in the per-frame culling path.
  return element.label?.trim() ? unionBounds([bounds, labelArea(element, nodes)])! : bounds
}

export function labelArea(element: ILabelElement, nodes: ReadonlyMap<string, IElement>): IBounds {
  if (element.type === 'edge') {
    const from = resolveEndpoint(element.from, nodes),
      to = resolveEndpoint(element.to, nodes)
    const center = connectorMidpoint(connectorPath(element, from, to))
    const scale = textSize(element.style, 'label') / 20
    return {
      x: center.x - 118 * scale,
      y: center.y - 45 * scale,
      width: 236 * scale,
      height: 90 * scale,
    }
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

export function labelLayout(
  element: ILabelElement,
  nodes: ReadonlyMap<string, IElement>,
  measured?: ITextLayout,
) {
  const area = labelArea(element, nodes)
  const padding = element.type === 'edge' ? 8 : 0
  const layout =
    measured ??
    wrapLabel(
      element.label ?? '',
      area.width - padding * 2,
      area.height - padding * 2,
      element.style,
    )
  const align = element.style.textAlign ?? 'center'
  return {
    ...layout,
    bounds: {
      x:
        area.x +
        (area.width - layout.width - padding * 2) *
          (align === 'left' ? 0 : align === 'right' ? 1 : 0.5),
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

export interface IHitTestOptions {
  readonly includeLocked?: boolean
  readonly includeHidden?: boolean
  readonly excluded?: ReadonlySet<string>
  readonly map?: ReadonlyMap<string, IElement>
  readonly locked?: ReadonlySet<string>
  readonly hidden?: ReadonlySet<string>
  readonly limit?: number
}

type ILabelBounds = (element: ILabelElement, nodes: ReadonlyMap<string, IElement>) => IBounds

function elementHit(
  element: IElement,
  point: IPoint,
  tolerance: number,
  map: ReadonlyMap<string, IElement>,
  nodesOnly: boolean,
  measuredLabelBounds?: ILabelBounds,
): boolean {
  if (element.type === 'edge') {
    if (nodesOnly) return false
    if (
      element.label?.trim() &&
      intersects(labelArea(element, map), { ...point, width: 0, height: 0 }) &&
      intersects(measuredLabelBounds?.(element, map) ?? labelLayout(element, map).bounds, {
        x: point.x - tolerance,
        y: point.y - tolerance,
        width: tolerance * 2,
        height: tolerance * 2,
      })
    )
      return true
    return connectorHit(
      element,
      connectorPath(element, resolveEndpoint(element.from, map), resolveEndpoint(element.to, map)),
      point,
      tolerance,
    )
  }
  if (
    !intersects(nodeBounds(element), {
      x: point.x - tolerance,
      y: point.y - tolerance,
      width: tolerance * 2,
      height: tolerance * 2,
    })
  )
    return false
  const local = nodeLocalPoint(element, point)
  if (element.type === 'stroke') {
    if (nodesOnly) return false
    const points = element.points.map(p => ({ x: p.x * element.width, y: p.y * element.height }))
    let start = points[0]
    for (let index = 1; index < points.length - 1; index++) {
      const control = points[index],
        next = points[index + 1]
      const end = { x: (control.x + next.x) / 2, y: (control.y + next.y) / 2 }
      if (quadraticHit(local, start, control, end, tolerance)) return true
      start = end
    }
    return segmentDistance(local, start, points[points.length - 1]) <= tolerance
  }
  if (
    local.x < -tolerance ||
    local.y < -tolerance ||
    local.x > element.width + tolerance ||
    local.y > element.height + tolerance
  )
    return false
  const dx = (local.x - element.width / 2) / (element.width / 2 + tolerance)
  const dy = (local.y - element.height / 2) / (element.height / 2 + tolerance)
  if (element.type === 'shape' && element.shape === 'ellipse' && dx * dx + dy * dy > 1) return false
  if (element.type === 'shape' && element.shape === 'diamond' && Math.abs(dx) + Math.abs(dy) > 1)
    return false
  return true
}

export function hitElements(
  elements: ReadonlyArray<IElement>,
  point: IPoint,
  tolerance: number,
  nodesOnly = false,
  measuredLabelBounds?: ILabelBounds,
  options: IHitTestOptions = {},
): IElement[] {
  const map = options.map ?? new Map(elements.map(element => [element.id, element]))
  const locked = options.locked ?? lockedElements(elements),
    hidden = options.hidden ?? hiddenElements(elements)
  const result: IElement[] = []
  for (let index = elements.length - 1; index >= 0; index--) {
    const element = elements[index]
    if (
      options.excluded?.has(element.id) ||
      (!options.includeHidden && hidden.has(element.id)) ||
      (!(options.includeLocked ?? nodesOnly) && locked.has(element.id))
    )
      continue
    if (elementHit(element, point, tolerance, map, nodesOnly, measuredLabelBounds)) {
      result.push(element)
      if (result.length >= (options.limit ?? Infinity)) return result
    }
  }
  return result
}

export function hitTest(
  elements: ReadonlyArray<IElement>,
  point: IPoint,
  tolerance: number,
  nodesOnly = false,
  measuredLabelBounds?: ILabelBounds,
  options: IHitTestOptions = {},
): IElement | undefined {
  return hitElements(elements, point, tolerance, nodesOnly, measuredLabelBounds, {
    ...options,
    limit: 1,
  })[0]
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
      ? {
          ...element,
          from: move(element.from),
          to: move(element.to),
          ...(element.controls
            ? {
                controls: element.controls.map(point => ({
                  ...point,
                  x: point.x + delta.x,
                  y: point.y + delta.y,
                })),
              }
            : {}),
        }
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
          ...(element.controls
            ? {
                controls: element.controls.map(point => ({
                  ...point,
                  x: point.x + 24,
                  y: point.y + 24,
                })),
              }
            : {}),
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
