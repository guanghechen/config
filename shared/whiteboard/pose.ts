import type { IBounds, INode, IPoint } from './model.ts'

export function normalizeAngle(degrees: number): number {
  const angle = (((degrees % 360) + 540) % 360) - 180
  return Math.abs(angle) < 1e-10 ? 0 : angle
}

export function rotatePoint(point: IPoint, center: IPoint, degrees: number): IPoint {
  const radians = (normalizeAngle(degrees) * Math.PI) / 180
  if (!radians) return { ...point }
  const x = point.x - center.x,
    y = point.y - center.y
  const cosine = Math.cos(radians),
    sine = Math.sin(radians)
  return { ...point, x: center.x + x * cosine - y * sine, y: center.y + x * sine + y * cosine }
}

export function nodePoint(node: INode, local: IPoint): IPoint {
  if (!normalizeAngle(node.rotation ?? 0) && !node.flipX && !node.flipY)
    return { x: node.x + local.x, y: node.y + local.y }
  const center = { x: node.x + node.width / 2, y: node.y + node.height / 2 }
  return rotatePoint(
    {
      x: center.x + (local.x - node.width / 2) * (node.flipX ? -1 : 1),
      y: center.y + (local.y - node.height / 2) * (node.flipY ? -1 : 1),
    },
    center,
    node.rotation ?? 0,
  )
}

export function nodeLocalPoint(node: INode, point: IPoint): IPoint {
  if (!normalizeAngle(node.rotation ?? 0) && !node.flipX && !node.flipY)
    return { x: point.x - node.x, y: point.y - node.y }
  const center = { x: node.x + node.width / 2, y: node.y + node.height / 2 }
  const local = rotatePoint(point, center, -(node.rotation ?? 0))
  return {
    x: (local.x - center.x) * (node.flipX ? -1 : 1) + node.width / 2,
    y: (local.y - center.y) * (node.flipY ? -1 : 1) + node.height / 2,
  }
}

export function nodeBounds(node: INode): IBounds {
  const angle = (normalizeAngle(node.rotation ?? 0) * Math.PI) / 180
  if (!angle) return node
  const cosine = Math.abs(Math.cos(angle)),
    sine = Math.abs(Math.sin(angle))
  const width = node.width * cosine + node.height * sine,
    height = node.width * sine + node.height * cosine
  return {
    x: node.x + (node.width - width) / 2,
    y: node.y + (node.height - height) / 2,
    width,
    height,
  }
}

// Keep the transformed local origin fixed when content-driven sizing changes the local box.
export function resizeNodeBox(node: INode, width: number, height: number): INode {
  if (node.width === width && node.height === height) return node
  if (!normalizeAngle(node.rotation ?? 0) && !node.flipX && !node.flipY)
    return { ...node, width, height }
  const origin = nodePoint(node, { x: 0, y: 0 })
  const offset = rotatePoint(
    { x: (width / 2) * (node.flipX ? -1 : 1), y: (height / 2) * (node.flipY ? -1 : 1) },
    { x: 0, y: 0 },
    node.rotation ?? 0,
  )
  return {
    ...node,
    x: origin.x + offset.x - width / 2,
    y: origin.y + offset.y - height / 2,
    width,
    height,
  }
}

export interface ITransformFrame extends IBounds {
  readonly rotation?: number
}

export function framePoint(frame: ITransformFrame, corner: IPoint): IPoint {
  return rotatePoint(
    { x: frame.x + corner.x * frame.width, y: frame.y + corner.y * frame.height },
    { x: frame.x + frame.width / 2, y: frame.y + frame.height / 2 },
    frame.rotation ?? 0,
  )
}

export function rotationHandle(frame: ITransformFrame, zoom: number): IPoint {
  return rotatePoint(
    { x: frame.x + frame.width / 2, y: frame.y - 28 / zoom },
    { x: frame.x + frame.width / 2, y: frame.y + frame.height / 2 },
    frame.rotation ?? 0,
  )
}
