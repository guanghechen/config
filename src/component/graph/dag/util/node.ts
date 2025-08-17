/* eslint-disable no-param-reassign */
import type { IGraphNode, IGraphNodeBounds } from '../types'

export const getNodeBounds = (node: IGraphNode): IGraphNodeBounds => {
  const { x, y } = node.position || { x: 0, y: 0 }
  const { width, height } = node.size || { width: 120, height: 60 }

  return {
    x: x - width / 2,
    y: y - height / 2,
    width,
    height,
  }
}

export const isPointInNode = (worldX: number, worldY: number, node: IGraphNode): boolean => {
  const bounds = getNodeBounds(node)

  return (
    worldX >= bounds.x &&
    worldX <= bounds.x + bounds.width &&
    worldY >= bounds.y &&
    worldY <= bounds.y + bounds.height
  )
}

export const measureText = (
  ctx: CanvasRenderingContext2D,
  text: string,
  font: string,
): { width: number; height: number } => {
  const previousFont = ctx.font
  ctx.font = font
  const metrics = ctx.measureText(text)
  ctx.font = previousFont

  return {
    width: metrics.width,
    height: metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent,
  }
}

export const truncateText = (
  ctx: CanvasRenderingContext2D,
  text: string,
  maxWidth: number,
  font: string,
): string => {
  const previousFont = ctx.font
  ctx.font = font

  if (ctx.measureText(text).width <= maxWidth) {
    ctx.font = previousFont
    return text
  }

  let truncated = text
  while (ctx.measureText(truncated + '...').width > maxWidth && truncated.length > 0) {
    truncated = truncated.slice(0, -1)
  }

  ctx.font = previousFont
  return truncated + '...'
}
