import React from 'react'
import { elementBounds, resolveEndpoint, unionBounds } from '@/shared/whiteboard/geometry'
import { connectorPath } from '@/shared/whiteboard/edges'
import { hiddenElements } from '@/shared/whiteboard/visibility'
import { cameraForBounds, viewportBounds } from '@/shared/whiteboard/navigation'
import type { IWhiteboardTheme } from './theme'
import type { BoardStore, IBoardSnapshot } from './store'

export const Minimap: React.FC<{
  snapshot: IBoardSnapshot
  store: BoardStore
  size: { width: number; height: number }
  theme: IWhiteboardTheme
}> = ({ snapshot, store, size, theme }) => {
  const document = React.useDeferredValue(snapshot.document)
  const canvas = React.useRef<HTMLCanvasElement>(null)
  const drag = React.useRef<number | null>(null)
  const scene = React.useMemo(() => {
    const hidden = hiddenElements(document.elements),
      map = new Map(document.elements.map(e => [e.id, e]))
    return document.elements
      .filter(e => !hidden.has(e.id))
      .map(e => ({
        bounds: elementBounds(e, map),
        path:
          e.type === 'edge'
            ? connectorPath(e, resolveEndpoint(e.from, map), resolveEndpoint(e.to, map))
            : null,
      }))
  }, [document])
  const bounds = React.useMemo(
    () =>
      unionBounds([...scene.map(item => item.bounds), ...(document.regions ?? [])]) ?? {
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      },
    [scene, document.regions],
  )
  const scale = Math.min(204 / Math.max(1, bounds.width), 124 / Math.max(1, bounds.height))
  const x = 110 - (bounds.x + bounds.width / 2) * scale,
    y = 70 - (bounds.y + bounds.height / 2) * scale
  React.useLayoutEffect(() => {
    const target = canvas.current!,
      ratio = window.devicePixelRatio || 1
    target.width = 220 * ratio
    target.height = 140 * ratio
    const ctx = target.getContext('2d')!
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, 220, 140)
    ctx.fillStyle = theme.muted
    ctx.globalAlpha = 0.45
    ctx.strokeStyle = theme.muted
    ctx.lineWidth = 0.7
    for (const item of scene) {
      if (item.path) {
        const points = item.path.points.map(p => ({ x: x + p.x * scale, y: y + p.y * scale }))
        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        if (item.path.curved)
          ctx.bezierCurveTo(
            points[1].x,
            points[1].y,
            points[2].x,
            points[2].y,
            points[3].x,
            points[3].y,
          )
        else for (const p of points.slice(1)) ctx.lineTo(p.x, p.y)
        ctx.stroke()
      } else {
        const rect = item.bounds
        ctx.fillRect(
          x + rect.x * scale,
          y + rect.y * scale,
          Math.max(1, rect.width * scale),
          Math.max(1, rect.height * scale),
        )
      }
    }
    ctx.globalAlpha = 1
    ctx.strokeStyle = theme.selection
    ctx.lineWidth = 1
    for (const rect of document.regions ?? [])
      ctx.strokeRect(
        x + rect.x * scale,
        y + rect.y * scale,
        rect.width * scale,
        rect.height * scale,
      )
  }, [scene, document.regions, scale, x, y, theme])
  const viewport = viewportBounds(snapshot.camera, size.width, size.height)
  const move = (event: React.PointerEvent<HTMLDivElement>): void => {
    const box = event.currentTarget.getBoundingClientRect(),
      camera = store.getSnapshot().camera
    const point = {
      x: (event.clientX - box.left - x) / scale,
      y: (event.clientY - box.top - y) / scale,
    }
    store.camera({
      ...camera,
      x: size.width / 2 - point.x * camera.zoom,
      y: size.height / 2 - point.y * camera.zoom,
    })
  }
  return (
    <div
      className="wb-minimap"
      data-wb-ui
      tabIndex={0}
      role="application"
      aria-label="Minimap"
      title="Click or drag to navigate; double-click to fit"
      onPointerDown={event => {
        if (event.button !== 0) return
        drag.current = event.pointerId
        event.currentTarget.setPointerCapture(event.pointerId)
        move(event)
        event.preventDefault()
      }}
      onPointerMove={event => {
        if (drag.current === event.pointerId) move(event)
      }}
      onPointerUp={() => {
        drag.current = null
      }}
      onPointerCancel={() => {
        drag.current = null
      }}
      onLostPointerCapture={() => {
        drag.current = null
      }}
      onDoubleClick={() => store.camera(cameraForBounds(bounds, size.width, size.height))}
      onKeyDown={event => {
        event.stopPropagation()
        const directions: Record<string, [number, number]> = {
          ArrowLeft: [50, 0],
          ArrowRight: [-50, 0],
          ArrowUp: [0, 50],
          ArrowDown: [0, -50],
        }
        const delta = directions[event.key]
        if (delta) {
          event.preventDefault()
          const camera = store.getSnapshot().camera
          store.camera({ ...camera, x: camera.x + delta[0], y: camera.y + delta[1] })
        } else if (event.key === 'Enter') {
          event.preventDefault()
          store.camera(cameraForBounds(bounds, size.width, size.height))
        }
      }}
    >
      <canvas ref={canvas} />
      <svg width="220" height="140" aria-hidden="true">
        <rect
          x={x + viewport.x * scale}
          y={y + viewport.y * scale}
          width={Math.max(2, viewport.width * scale)}
          height={Math.max(2, viewport.height * scale)}
          fill="none"
          stroke={theme.selection}
          strokeWidth="2"
        />
      </svg>
    </div>
  )
}
