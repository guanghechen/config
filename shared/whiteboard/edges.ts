import type { IArrowhead, IBounds, IEdge, IPoint } from './model.ts'
import { cubicHit, cubicPoint, segmentDistance } from './curves.ts'

export interface IConnectorPath {
  readonly points: ReadonlyArray<IPoint>
  readonly curved: boolean
}

export function connectorControls(edge: IEdge, from: IPoint, to: IPoint): ReadonlyArray<IPoint> {
  if (!edge.routing || edge.routing === 'straight') return []
  if (edge.controls) return edge.controls
  const dx = to.x - from.x,
    dy = to.y - from.y
  if (edge.routing === 'curve') {
    if (!dx && !dy)
      return [
        { x: from.x + 80, y: from.y - 80 },
        { x: from.x - 80, y: from.y - 80 },
      ]
    return Math.abs(dx) >= Math.abs(dy)
      ? [
          { x: from.x + dx / 3, y: from.y },
          { x: to.x - dx / 3, y: to.y },
        ]
      : [
          { x: from.x, y: from.y + dy / 3 },
          { x: to.x, y: to.y - dy / 3 },
        ]
  }
  if (!dx || !dy) return [{ x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 }]
  return [
    { x: (from.x + to.x) / 2, y: from.y },
    { x: (from.x + to.x) / 2, y: to.y },
  ]
}

export function connectorPath(edge: IEdge, from: IPoint, to: IPoint): IConnectorPath {
  return {
    points: [from, ...connectorControls(edge, from, to), to],
    curved: edge.routing === 'curve',
  }
}

export function connectorBounds(path: IConnectorPath): IBounds {
  const xs = path.points.map(point => point.x),
    ys = path.points.map(point => point.y)
  const x = Math.min(...xs),
    y = Math.min(...ys)
  // The control hull conservatively contains every Bézier point, including large bends.
  return { x, y, width: Math.max(1, Math.max(...xs) - x), height: Math.max(1, Math.max(...ys) - y) }
}

export function connectorMidpoint(path: IConnectorPath): IPoint {
  const points = path.points
  if (path.curved) return cubicPoint(points[0], points[1], points[2], points[3], 0.5)
  const lengths = points
    .slice(1)
    .map((point, index) => Math.hypot(point.x - points[index].x, point.y - points[index].y))
  let remaining = lengths.reduce((total, value) => total + value, 0) / 2
  for (let index = 0; index < lengths.length; index++) {
    if (remaining <= lengths[index]) {
      const t = lengths[index] ? remaining / lengths[index] : 0
      return {
        x: points[index].x + (points[index + 1].x - points[index].x) * t,
        y: points[index].y + (points[index + 1].y - points[index].y) * t,
      }
    }
    remaining -= lengths[index]
  }
  return points[0]
}

export function connectorArrowheads(
  path: IConnectorPath,
  width: number,
  start: IArrowhead = 'none',
  end: IArrowhead = 'arrow',
): ReadonlyArray<ReadonlyArray<IPoint>> {
  const heads: IPoint[][] = []
  for (const [reverse, enabled] of [
    [true, start],
    [false, end],
  ] as const) {
    if (enabled === 'none') continue
    const points = reverse ? [...path.points].reverse() : path.points
    const tip = points.at(-1)!
    const previous = [...points]
      .reverse()
      .find(point => Math.hypot(point.x - tip.x, point.y - tip.y) > 1e-6)
    if (!previous) continue
    const length = Math.hypot(tip.x - previous.x, tip.y - previous.y)
    const size = Math.min(10 + width, length * 0.45)
    const angle = Math.atan2(tip.y - previous.y, tip.x - previous.x)
    heads.push(
      [-1, 0, 1].map(sign =>
        sign === 0
          ? tip
          : {
              x: tip.x - size * Math.cos(angle + sign * 0.4),
              y: tip.y - size * Math.sin(angle + sign * 0.4),
            },
      ),
    )
  }
  return heads
}

export function connectorHit(
  edge: IEdge,
  path: IConnectorPath,
  point: IPoint,
  tolerance: number,
): boolean {
  const inkTolerance = tolerance + edge.style.strokeWidth / 2 + edge.style.roughness * 1.6
  const points = path.points
  if (
    path.curved
      ? cubicHit(point, points[0], points[1], points[2], points[3], inkTolerance)
      : points.some(
          (end, index) =>
            index > 0 && segmentDistance(point, points[index - 1], end) <= inkTolerance,
        )
  )
    return true
  return connectorArrowheads(path, edge.style.strokeWidth, edge.arrowStart, edge.arrowEnd).some(
    head =>
      segmentDistance(point, head[0], head[1]) <= inkTolerance ||
      segmentDistance(point, head[1], head[2]) <= inkTolerance,
  )
}

export function connectorControlAt(
  edge: IEdge,
  from: IPoint,
  to: IPoint,
  point: IPoint,
  tolerance: number,
): number {
  return connectorControls(edge, from, to).findIndex(
    control => Math.hypot(control.x - point.x, control.y - point.y) <= tolerance,
  )
}

export function addConnectorBend(edge: IEdge, from: IPoint, to: IPoint): IEdge {
  const controls = connectorControls(edge, from, to)
  const points = [from, ...controls, to]
  let longest = 0
  for (let index = 1; index < points.length - 1; index++) {
    if (
      Math.hypot(points[index + 1].x - points[index].x, points[index + 1].y - points[index].y) >
      Math.hypot(
        points[longest + 1].x - points[longest].x,
        points[longest + 1].y - points[longest].y,
      )
    )
      longest = index
  }
  return {
    ...edge,
    routing: 'polyline',
    controls: [
      ...controls.slice(0, longest),
      {
        x: (points[longest].x + points[longest + 1].x) / 2,
        y: (points[longest].y + points[longest + 1].y) / 2,
      },
      ...controls.slice(longest),
    ],
  }
}
