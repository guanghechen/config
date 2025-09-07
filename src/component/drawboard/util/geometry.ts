import type { IDrawboardElement } from '../types/elements'

export interface IPoint {
  x: number
  y: number
}

export interface IBounds {
  x: number
  y: number
  width: number
  height: number
}

/**
 * Calculate the distance between two points
 */
export function distance(p1: IPoint, p2: IPoint): number {
  return Math.sqrt(Math.pow(p2.x - p1.x, 2) + Math.pow(p2.y - p1.y, 2))
}

/**
 * Check if a point is within a given distance of another point
 */
export function isPointNear(point: IPoint, target: IPoint, threshold: number = 10): boolean {
  return distance(point, target) <= threshold
}

/**
 * Check if a point is inside a rectangle
 */
export function isPointInRectangle(point: IPoint, bounds: IBounds): boolean {
  return (
    point.x >= bounds.x &&
    point.x <= bounds.x + bounds.width &&
    point.y >= bounds.y &&
    point.y <= bounds.y + bounds.height
  )
}

/**
 * Check if a point is inside a circle/ellipse
 */
export function isPointInEllipse(
  point: IPoint,
  center: IPoint,
  radiusX: number,
  radiusY: number,
): boolean {
  const dx = point.x - center.x
  const dy = point.y - center.y
  return (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY) <= 1
}

/**
 * Check if a point is near a line segment
 */
export function isPointNearLine(
  point: IPoint,
  lineStart: IPoint,
  lineEnd: IPoint,
  threshold: number = 5,
): boolean {
  const A = point.x - lineStart.x
  const B = point.y - lineStart.y
  const C = lineEnd.x - lineStart.x
  const D = lineEnd.y - lineStart.y

  const dot = A * C + B * D
  const lenSq = C * C + D * D

  if (lenSq === 0) {
    return distance(point, lineStart) <= threshold
  }

  const param = dot / lenSq

  let xx: number, yy: number

  if (param < 0) {
    xx = lineStart.x
    yy = lineStart.y
  } else if (param > 1) {
    xx = lineEnd.x
    yy = lineEnd.y
  } else {
    xx = lineStart.x + param * C
    yy = lineStart.y + param * D
  }

  const dx = point.x - xx
  const dy = point.y - yy
  return Math.sqrt(dx * dx + dy * dy) <= threshold
}

/**
 * Get the bounding box of an element
 */
export function getElementBounds(element: IDrawboardElement): IBounds {
  return {
    x: Math.min(element.x, element.x + element.width),
    y: Math.min(element.y, element.y + element.height),
    width: Math.abs(element.width),
    height: Math.abs(element.height),
  }
}

/**
 * Check if a point hits an element
 */
export function hitTestElement(element: IDrawboardElement, point: IPoint): boolean {
  const bounds = getElementBounds(element)

  switch (element.type) {
    case 'rectangle':
      return isPointInRectangle(point, bounds)

    case 'circle': {
      const center = {
        x: bounds.x + bounds.width / 2,
        y: bounds.y + bounds.height / 2,
      }
      return isPointInEllipse(point, center, bounds.width / 2, bounds.height / 2)
    }

    case 'line':
    case 'arrow': {
      const lineElement = element as any
      if (lineElement.points.length < 2) return false

      for (let i = 0; i < lineElement.points.length - 1; i++) {
        const start = {
          x: element.x + lineElement.points[i][0],
          y: element.y + lineElement.points[i][1],
        }
        const end = {
          x: element.x + lineElement.points[i + 1][0],
          y: element.y + lineElement.points[i + 1][1],
        }

        if (isPointNearLine(point, start, end, element.strokeWidth + 5)) {
          return true
        }
      }
      return false
    }

    default:
      return false
  }
}

/**
 * Snap a point to grid
 */
export function snapToGrid(point: IPoint, gridSize: number): IPoint {
  return {
    x: Math.round(point.x / gridSize) * gridSize,
    y: Math.round(point.y / gridSize) * gridSize,
  }
}

/**
 * Rotate a point around a center
 */
export function rotatePoint(point: IPoint, center: IPoint, angle: number): IPoint {
  const cos = Math.cos(angle)
  const sin = Math.sin(angle)
  const dx = point.x - center.x
  const dy = point.y - center.y

  return {
    x: center.x + dx * cos - dy * sin,
    y: center.y + dx * sin + dy * cos,
  }
}

/**
 * Calculate angle between two points
 */
export function angleBetweenPoints(p1: IPoint, p2: IPoint): number {
  return Math.atan2(p2.y - p1.y, p2.x - p1.x)
}

/**
 * Normalize angle to [0, 2π]
 */
export function normalizeAngle(angle: number): number {
  let normalizedAngle = angle
  while (normalizedAngle < 0) normalizedAngle += 2 * Math.PI
  while (normalizedAngle >= 2 * Math.PI) normalizedAngle -= 2 * Math.PI
  return normalizedAngle
}
