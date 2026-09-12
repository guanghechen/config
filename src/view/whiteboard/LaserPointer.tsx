import React from 'react'
import type { IPoint } from '@/shared/whiteboard/model'

export interface ILaserPointer {
  point: (point: IPoint) => void
  clear: () => void
}
export const LaserPointer = React.forwardRef<
  ILaserPointer,
  { size: { width: number; height: number } }
>(({ size }, ref) => {
  const canvas = React.useRef<HTMLCanvasElement>(null)
  const points = React.useRef<Array<IPoint & { time: number }>>([])
  const frame = React.useRef(0)
  const draw = React.useCallback(() => {
    const target = canvas.current
    if (!target) return
    const now = performance.now(),
      ratio = window.devicePixelRatio || 1
    const rect = target.getBoundingClientRect()
    if (
      target.width !== Math.round(rect.width * ratio) ||
      target.height !== Math.round(rect.height * ratio)
    ) {
      target.width = Math.round(rect.width * ratio)
      target.height = Math.round(rect.height * ratio)
    }
    const ctx = target.getContext('2d')!
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, rect.width, rect.height)
    points.current = points.current.filter(p => now - p.time < 900)
    ctx.strokeStyle = '#ef4444'
    ctx.fillStyle = '#ef4444'
    ctx.lineWidth = 4
    ctx.lineCap = 'round'
    for (let i = 1; i < points.current.length; i++) {
      const p = points.current[i],
        previous = points.current[i - 1]
      ctx.globalAlpha = Math.max(0, 1 - (now - p.time) / 900)
      ctx.beginPath()
      ctx.moveTo(previous.x, previous.y)
      ctx.lineTo(p.x, p.y)
      ctx.stroke()
    }
    const last = points.current.at(-1)
    if (last) {
      ctx.globalAlpha = Math.max(0, 1 - (now - last.time) / 900)
      ctx.beginPath()
      ctx.arc(last.x, last.y, 5, 0, Math.PI * 2)
      ctx.fill()
    }
    frame.current = points.current.length ? requestAnimationFrame(draw) : 0
  }, [])
  React.useImperativeHandle(
    ref,
    () => ({
      point: point => {
        points.current.push({ ...point, time: performance.now() })
        if (points.current.length > 160) points.current.shift()
        if (!frame.current) frame.current = requestAnimationFrame(draw)
      },
      clear: () => {
        points.current = []
        if (!frame.current) frame.current = requestAnimationFrame(draw)
      },
    }),
    [draw],
  )
  React.useEffect(() => () => cancelAnimationFrame(frame.current), [])
  return (
    <canvas
      ref={canvas}
      className="wb-laser"
      aria-hidden="true"
      style={{ width: size.width, height: size.height }}
    />
  )
})
LaserPointer.displayName = 'WhiteboardLaserPointer'
