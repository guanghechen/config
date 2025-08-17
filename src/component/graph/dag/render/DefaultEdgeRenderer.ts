/* eslint-disable no-param-reassign */
import type { IEdgeRenderer, IEdgeStyle, IGraphEdge, IGraphNode } from '../types'

export class DefaultEdgeRenderer implements IEdgeRenderer {
  private animationOffset = 0

  public render(
    ctx: CanvasRenderingContext2D,
    _edge: IGraphEdge,
    sourceNode: IGraphNode,
    targetNode: IGraphNode,
    style: IEdgeStyle,
  ): void {
    const sourcePos = sourceNode.position || { x: 0, y: 0 }
    const targetPos = targetNode.position || { x: 0, y: 0 }

    const sourceSize = sourceNode.size || { width: 120, height: 60 }
    const targetSize = targetNode.size || { width: 120, height: 60 }

    const { startX, startY, endX, endY } = this.calculateEdgeEndpoints(
      sourcePos,
      sourceSize,
      targetPos,
      targetSize,
    )

    ctx.save()
    ctx.strokeStyle = style.stroke
    ctx.lineWidth = style.strokeWidth

    if (style.strokeDasharray) {
      ctx.setLineDash(style.strokeDasharray.split(',').map(Number))
    } else {
      ctx.setLineDash([])
    }

    ctx.beginPath()
    ctx.moveTo(startX, startY)

    const controlPointOffset = 50
    const midX = (startX + endX) / 2

    ctx.quadraticCurveTo(midX, startY + controlPointOffset, endX, endY)
    ctx.stroke()

    this.drawArrow(ctx, endX, endY, startX, startY, style.arrowSize)

    if (style.animated) {
      this.drawAnimation(ctx, startX, startY, endX, endY)
    }

    ctx.restore()
  }

  private calculateEdgeEndpoints(
    sourcePos: { x: number; y: number },
    sourceSize: { width: number; height: number },
    targetPos: { x: number; y: number },
    targetSize: { width: number; height: number },
  ): { startX: number; startY: number; endX: number; endY: number } {
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

  private drawArrow(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    fromX: number,
    fromY: number,
    size: number,
  ): void {
    const angle = Math.atan2(y - fromY, x - fromX)

    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(angle)

    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(-size, -size / 2)
    ctx.lineTo(-size, size / 2)
    ctx.closePath()

    const currentStrokeStyle = ctx.strokeStyle
    ctx.fillStyle = currentStrokeStyle
    ctx.fill()

    ctx.restore()
  }

  private drawAnimation(
    ctx: CanvasRenderingContext2D,
    startX: number,
    startY: number,
    endX: number,
    endY: number,
  ): void {
    const numDots = 3
    const dotSpacing = 20

    for (let i = 0; i < numDots; i++) {
      const progress = ((this.animationOffset + i * dotSpacing) % 100) / 100
      const x = startX + (endX - startX) * progress
      const y = startY + (endY - startY) * progress

      ctx.save()
      const currentStrokeStyle = ctx.strokeStyle
      ctx.fillStyle = currentStrokeStyle
      ctx.globalAlpha = 0.7
      ctx.beginPath()
      ctx.arc(x, y, 3, 0, 2 * Math.PI)
      ctx.fill()
      ctx.restore()
    }

    this.animationOffset = (this.animationOffset + 2) % 100
  }
}
