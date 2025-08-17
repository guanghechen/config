import type { IGraphNode } from '../types'

export const calculateEdgeEndpoints = (sourceNode: IGraphNode, targetNode: IGraphNode) => {
  const sourcePos = sourceNode.position || { x: 0, y: 0 }
  const targetPos = targetNode.position || { x: 0, y: 0 }
  const sourceSize = sourceNode.size || { width: 120, height: 60 }
  const targetSize = targetNode.size || { width: 120, height: 60 }

  const dx = targetPos.x - sourcePos.x
  const dy = targetPos.y - sourcePos.y
  const distance = Math.sqrt(dx * dx + dy * dy)

  if (distance === 0) {
    return {
      startX: sourcePos.x,
      startY: sourcePos.y,
      endX: targetPos.x,
      endY: targetPos.y,
    }
  }

  const unitX = dx / distance
  const unitY = dy / distance

  const startX = sourcePos.x + unitX * (sourceSize.height / 2)
  const startY = sourcePos.y + unitY * (sourceSize.height / 2)

  const endX = targetPos.x - unitX * (targetSize.height / 2)
  const endY = targetPos.y - unitY * (targetSize.height / 2)

  return { startX, startY, endX, endY }
}

export const drawBezierCurve = (
  ctx: CanvasRenderingContext2D,
  startX: number,
  startY: number,
  endX: number,
  endY: number,
  curvature: number = 0.3,
) => {
  const controlPointOffset = Math.abs(endY - startY) * curvature
  const midX = (startX + endX) / 2
  const controlY = startY + controlPointOffset

  ctx.beginPath()
  ctx.moveTo(startX, startY)
  ctx.quadraticCurveTo(midX, controlY, endX, endY)
  ctx.stroke()
}

export const drawArrowHead = (
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  angle: number,
  size: number,
) => {
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(angle)

  ctx.beginPath()
  ctx.moveTo(0, 0)
  ctx.lineTo(-size, -size / 2)
  ctx.lineTo(-size, size / 2)
  ctx.closePath()

  ctx.fillStyle = ctx.strokeStyle
  ctx.fill()

  ctx.restore()
}
