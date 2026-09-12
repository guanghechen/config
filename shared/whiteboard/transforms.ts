import { resolveEndpoint, unionBounds } from './geometry.ts'
import type { IBounds, IElement, IEndpoint, IPoint } from './model.ts'
import { framePoint, nodeBounds, normalizeAngle, rotatePoint } from './pose.ts'
import type { ITransformFrame } from './pose.ts'
import { connectorControls } from './edges.ts'

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
): ITransformFrame | null {
  const single = elements.find(element => selected.size === 1 && selected.has(element.id))
  if (single && single.type !== 'edge' && normalizeAngle(single.rotation ?? 0))
    return {
      x: single.x,
      y: single.y,
      width: single.width,
      height: single.height,
      rotation: single.rotation,
    }
  const bounds: IBounds[] = []
  let nodes = 0
  for (const element of elements) {
    if (!selected.has(element.id)) continue
    if (element.type !== 'edge') {
      bounds.push(nodeBounds(element))
      nodes += 1
    } else {
      for (const endpoint of [element.from, element.to]) {
        if (!endpoint.nodeId) bounds.push({ ...endpoint, width: 0, height: 0 })
      }
      for (const control of element.controls ?? []) bounds.push({ ...control, width: 0, height: 0 })
    }
  }
  return nodes ? unionBounds(bounds) : null
}

export function resizeCornerAt(
  bounds: ITransformFrame,
  point: IPoint,
  tolerance: number,
): IPoint | undefined {
  let nearest: IPoint | undefined
  let distance = tolerance
  for (const corner of RESIZE_CORNERS) {
    const position = framePoint(bounds, corner)
    const current = Math.hypot(point.x - position.x, point.y - position.y)
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
  bounds: ITransformFrame,
  corner: IPoint,
  point: IPoint,
  preserveAspect: boolean,
): ReadonlyArray<IElement> {
  if (bounds.rotation) {
    const node = elements.find(element => selected.has(element.id))
    if (!node || node.type === 'edge') return elements
    const anchor = framePoint(bounds, { x: 1 - corner.x, y: 1 - corner.y })
    const local = rotatePoint(point, anchor, -bounds.rotation)
    let width = (local.x - anchor.x) * (corner.x ? 1 : -1),
      height = (local.y - anchor.y) * (corner.y ? 1 : -1)
    const minWidth = Math.min(16, node.width),
      minHeight = Math.min(16, node.height)
    if (preserveAspect) {
      const sx = width / node.width,
        sy = height / node.height
      const scale = Math.max(
        minWidth / node.width,
        minHeight / node.height,
        Math.abs(sx - 1) > Math.abs(sy - 1) ? sx : sy,
      )
      width = node.width * scale
      height = node.height * scale
    } else {
      width = Math.max(minWidth, width)
      height = Math.max(minHeight, height)
    }
    if (Math.abs(width - node.width) < 1e-9 && Math.abs(height - node.height) < 1e-9)
      return elements
    const center = rotatePoint(
      { x: anchor.x + (corner.x - 0.5) * width, y: anchor.y + (corner.y - 0.5) * height },
      anchor,
      bounds.rotation,
    )
    return elements.map(element =>
      element !== node
        ? element
        : {
            ...node,
            x: center.x - width / 2,
            y: center.y - height / 2,
            width,
            height,
            ...((node.type === 'text' || node.type === 'shape') && node.autoSize
              ? { autoSize: false }
              : {}),
          },
    )
  }
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
    const sideways = Math.abs(normalizeAngle(element.rotation ?? 0)) === 90
    const width = sideways ? element.height : element.width,
      height = sideways ? element.width : element.height
    minX = Math.max(minX, Math.min(16, width) / width)
    minY = Math.max(minY, Math.min(16, height) / height)
  }
  const rotated = elements.some(
    element =>
      selected.has(element.id) &&
      element.type !== 'edge' &&
      Math.abs(normalizeAngle(element.rotation ?? 0) % 90) > 1e-9,
  )
  if (preserveAspect || rotated) {
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
    const sideways =
      element.type !== 'edge' && Math.abs(normalizeAngle(element.rotation ?? 0)) === 90
    const center =
      element.type !== 'edge'
        ? transform({ x: element.x + element.width / 2, y: element.y + element.height / 2 })
        : null
    return element.type === 'edge'
      ? {
          ...element,
          from: endpoint(element.from),
          to: endpoint(element.to),
          ...(element.controls
            ? { controls: element.controls.map(point => ({ ...point, ...transform(point) })) }
            : {}),
        }
      : {
          ...element,
          ...(sideways
            ? {
                x: center!.x - (element.width * scaleY) / 2,
                y: center!.y - (element.height * scaleX) / 2,
              }
            : transform(element)),
          width: element.width * (sideways ? scaleY : scaleX),
          height: element.height * (sideways ? scaleX : scaleY),
          ...((element.type === 'text' || element.type === 'shape') && element.autoSize
            ? { autoSize: false }
            : {}),
        }
  })
}

export function transformBounds(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): ITransformFrame | null {
  const members = elements.filter(element => selected.has(element.id))
  if (!members.length) return null
  if (
    members.every(
      element =>
        element.type === 'edge' &&
        element.from.nodeId &&
        element.to.nodeId &&
        (!element.routing || element.routing === 'straight'),
    )
  )
    return null
  if (members.length === 1 && members[0].type !== 'edge') {
    const node = members[0]
    return { x: node.x, y: node.y, width: node.width, height: node.height, rotation: node.rotation }
  }
  const map = new Map(elements.map(element => [element.id, element]))
  const hasNodes = members.some(element => element.type !== 'edge')
  const boxes: IBounds[] = []
  for (const element of members) {
    if (element.type !== 'edge') {
      boxes.push(nodeBounds(element))
      continue
    }
    const from = resolveEndpoint(element.from, map),
      to = resolveEndpoint(element.to, map)
    for (const [endpoint, point] of [
      [element.from, from],
      [element.to, to],
    ] as const)
      if (!hasNodes || !endpoint.nodeId) boxes.push({ ...point, width: 0, height: 0 })
    for (const control of connectorControls(element, from, to))
      boxes.push({ ...control, width: 0, height: 0 })
  }
  if (!boxes.length) return null
  let x = Infinity,
    y = Infinity,
    right = -Infinity,
    bottom = -Infinity
  for (const box of boxes) {
    x = Math.min(x, box.x)
    y = Math.min(y, box.y)
    right = Math.max(right, box.x + box.width)
    bottom = Math.max(bottom, box.y + box.height)
  }
  const width = Math.max(1, right - x),
    height = Math.max(1, bottom - y)
  return { x: (x + right - width) / 2, y: (y + bottom - height) / 2, width, height }
}

export function transformPivot(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  frame: ITransformFrame,
): IPoint {
  const single =
    selected.size === 1 ? elements.find(element => selected.has(element.id)) : undefined
  if (single?.type === 'edge' && !!single.from.nodeId !== !!single.to.nodeId) {
    const map = new Map(elements.map(element => [element.id, element]))
    return resolveEndpoint(single.from.nodeId ? single.from : single.to, map)
  }
  return { x: frame.x + frame.width / 2, y: frame.y + frame.height / 2 }
}

export function rotateElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  degrees: number,
  origin?: IPoint,
): ReadonlyArray<IElement> {
  const angle = normalizeAngle(degrees),
    frame = transformBounds(elements, selected)
  if (!angle || !frame) return elements
  const pivot = origin ?? transformPivot(elements, selected, frame)
  const map = new Map(elements.map(element => [element.id, element]))
  return elements.map(element => {
    if (!selected.has(element.id)) return element
    if (element.type === 'edge') {
      const controls = connectorControls(
        element,
        resolveEndpoint(element.from, map),
        resolveEndpoint(element.to, map),
      )
      return {
        ...element,
        from: element.from.nodeId ? element.from : rotatePoint(element.from, pivot, angle),
        to: element.to.nodeId ? element.to : rotatePoint(element.to, pivot, angle),
        ...(element.routing && element.routing !== 'straight'
          ? { controls: controls.map(point => rotatePoint(point, pivot, angle)) }
          : {}),
      }
    }
    const center = rotatePoint(
      { x: element.x + element.width / 2, y: element.y + element.height / 2 },
      pivot,
      angle,
    )
    return {
      ...element,
      x: center.x - element.width / 2,
      y: center.y - element.height / 2,
      rotation: normalizeAngle((element.rotation ?? 0) + angle),
    }
  })
}

export function flipElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  axis: 'x' | 'y',
): ReadonlyArray<IElement> {
  const frame = transformBounds(elements, selected)
  if (!frame) return elements
  const pivot = transformPivot(elements, selected, frame)
  const reflect = (point: IPoint): IPoint => ({ ...point, [axis]: 2 * pivot[axis] - point[axis] })
  const map = new Map(elements.map(element => [element.id, element]))
  return elements.map(element => {
    if (!selected.has(element.id)) return element
    if (element.type === 'edge') {
      const controls = connectorControls(
        element,
        resolveEndpoint(element.from, map),
        resolveEndpoint(element.to, map),
      )
      return {
        ...element,
        from: element.from.nodeId ? element.from : reflect(element.from),
        to: element.to.nodeId ? element.to : reflect(element.to),
        ...(element.routing && element.routing !== 'straight'
          ? { controls: controls.map(reflect) }
          : {}),
      }
    }
    const center = reflect({ x: element.x + element.width / 2, y: element.y + element.height / 2 })
    return {
      ...element,
      x: center.x - element.width / 2,
      y: center.y - element.height / 2,
      rotation: normalizeAngle(-(element.rotation ?? 0)),
      ...(axis === 'x' ? { flipX: !element.flipX } : { flipY: !element.flipY }),
    }
  })
}
