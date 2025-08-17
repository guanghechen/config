/* eslint-disable no-param-reassign */
import type { IGraphNode, IGraphNodeRenderer, IGraphNodeStyle } from '../types'

export class DefaultNodeRenderer implements IGraphNodeRenderer {
  public render(
    ctx: CanvasRenderingContext2D,
    node: IGraphNode,
    style: IGraphNodeStyle,
    isHovered: boolean,
    isSelected: boolean,
  ): void {
    const { x, y } = node.position || { x: 0, y: 0 }
    const { width, height } = node.size || { width: 120, height: 60 }

    ctx.fillStyle = isHovered ? this.lightenColor(style.fill) : style.fill
    ctx.strokeStyle = isSelected ? '#3b82f6' : style.stroke
    ctx.lineWidth = isSelected ? style.strokeWidth * 2 : style.strokeWidth

    this.drawRoundedRect(ctx, x - width / 2, y - height / 2, width, height, style.radius)
    ctx.fill()
    ctx.stroke()

    ctx.fillStyle = style.textColor
    ctx.font = `${style.fontSize}px ${style.fontFamily}`
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    const label = this.truncateText(ctx, node.id, width - 20)
    ctx.fillText(label, x, y)

    if (node.data) {
      ctx.fillStyle = '#10b981'
      ctx.beginPath()
      ctx.arc(x + width / 2 - 8, y - height / 2 + 8, 4, 0, 2 * Math.PI)
      ctx.fill()
    }
  }

  public getNodeBounds(node: IGraphNode): { x: number; y: number; width: number; height: number } {
    const { x, y } = node.position || { x: 0, y: 0 }
    const { width, height } = node.size || { width: 120, height: 60 }

    return {
      x: x - width / 2,
      y: y - height / 2,
      width,
      height,
    }
  }

  private drawRoundedRect(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number,
  ): void {
    ctx.beginPath()
    ctx.moveTo(x + radius, y)
    ctx.lineTo(x + width - radius, y)
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius)
    ctx.lineTo(x + width, y + height - radius)
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
    ctx.lineTo(x + radius, y + height)
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius)
    ctx.lineTo(x, y + radius)
    ctx.quadraticCurveTo(x, y, x + radius, y)
    ctx.closePath()
  }

  private truncateText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string {
    if (ctx.measureText(text).width <= maxWidth) return text

    let truncated = text
    while (ctx.measureText(truncated + '...').width > maxWidth && truncated.length > 0) {
      truncated = truncated.slice(0, -1)
    }

    return truncated + '...'
  }

  private lightenColor(color: string): string {
    const hex = color.replace('#', '')
    const r = Math.min(255, parseInt(hex.substring(0, 2), 16) + 20)
    const g = Math.min(255, parseInt(hex.substring(2, 4), 16) + 20)
    const b = Math.min(255, parseInt(hex.substring(4, 6), 16) + 20)

    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
  }
}
