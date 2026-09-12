import type { IBounds, ICamera, IPoint } from './model.ts'

export function viewportBounds(camera: ICamera, width: number, height: number): IBounds {
  return {
    x: -camera.x / camera.zoom,
    y: -camera.y / camera.zoom,
    width: width / camera.zoom,
    height: height / camera.zoom,
  }
}

export function cameraForBounds(bounds: IBounds, width: number, height: number): ICamera {
  const zoom = Math.max(
    0.05,
    Math.min(2, Math.max(1, width - 160) / bounds.width, Math.max(1, height - 160) / bounds.height),
  )
  return {
    x: width / 2 - (bounds.x + bounds.width / 2) * zoom,
    y: height / 2 - (bounds.y + bounds.height / 2) * zoom,
    zoom,
  }
}

export function touchCamera(
  camera: ICamera,
  start: ReadonlyArray<IPoint>,
  current: ReadonlyArray<IPoint>,
): ICamera {
  if (start.length < 2 || current.length < 2) return camera
  const midpoint = (points: ReadonlyArray<IPoint>): IPoint => ({
    x: (points[0].x + points[1].x) / 2,
    y: (points[0].y + points[1].y) / 2,
  })
  const a = midpoint(start),
    b = midpoint(current)
  const distance = (points: ReadonlyArray<IPoint>): number =>
    Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y)
  const zoom = Math.max(
    0.05,
    Math.min(4, (camera.zoom * distance(current)) / Math.max(1, distance(start))),
  )
  return {
    x: b.x - ((a.x - camera.x) / camera.zoom) * zoom,
    y: b.y - ((a.y - camera.y) / camera.zoom) * zoom,
    zoom,
  }
}
