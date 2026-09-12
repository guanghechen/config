import type { IPoint } from './model.ts'

export function segmentDistance(point: IPoint, a: IPoint, b: IPoint): number {
  const dx = b.x - a.x,
    dy = b.y - a.y
  const t = Math.max(
    0,
    Math.min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy || 1)),
  )
  return Math.hypot(point.x - a.x - t * dx, point.y - a.y - t * dy)
}

export function quadraticHit(
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
  const left = midpoint(a, control),
    right = midpoint(control, b),
    middle = midpoint(left, right)
  return (
    quadraticHit(point, a, left, middle, tolerance, depth + 1) ||
    quadraticHit(point, middle, right, b, tolerance, depth + 1)
  )
}

function midpoint(a: IPoint, b: IPoint): IPoint {
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

export function cubicPoint(a: IPoint, c1: IPoint, c2: IPoint, b: IPoint, t: number): IPoint {
  const s = 1 - t
  return {
    x: s ** 3 * a.x + 3 * s * s * t * c1.x + 3 * s * t * t * c2.x + t ** 3 * b.x,
    y: s ** 3 * a.y + 3 * s * s * t * c1.y + 3 * s * t * t * c2.y + t ** 3 * b.y,
  }
}

export function cubicHit(
  point: IPoint,
  a: IPoint,
  c1: IPoint,
  c2: IPoint,
  b: IPoint,
  tolerance: number,
  depth = 0,
): boolean {
  if (
    point.x < Math.min(a.x, c1.x, c2.x, b.x) - tolerance ||
    point.x > Math.max(a.x, c1.x, c2.x, b.x) + tolerance ||
    point.y < Math.min(a.y, c1.y, c2.y, b.y) - tolerance ||
    point.y > Math.max(a.y, c1.y, c2.y, b.y) + tolerance
  )
    return false
  if (
    depth === 16 ||
    Math.max(segmentDistance(c1, a, b), segmentDistance(c2, a, b)) <= tolerance / 2
  )
    return segmentDistance(point, a, b) <= tolerance
  const a1 = midpoint(a, c1),
    c12 = midpoint(c1, c2),
    b2 = midpoint(c2, b)
  const left = midpoint(a1, c12),
    right = midpoint(c12, b2),
    middle = midpoint(left, right)
  return (
    cubicHit(point, a, a1, left, middle, tolerance, depth + 1) ||
    cubicHit(point, middle, right, b2, b, tolerance, depth + 1)
  )
}
