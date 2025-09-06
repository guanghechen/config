import rough from 'roughjs'
import type { RoughCanvas } from 'roughjs/bin/canvas'
import type {
  DrawboardElement,
  IDrawboardArrowElement,
  IDrawboardCircleElement,
  IDrawboardLineElement,
  IDrawboardRectangleElement,
} from '../types/elements'

export class RoughRenderer {
  private rc: RoughCanvas
  private context: CanvasRenderingContext2D

  constructor(canvas: HTMLCanvasElement) {
    this.context = canvas.getContext('2d')!
    this.rc = rough.canvas(canvas)
  }

  public renderElement(element: DrawboardElement): void {
    const options = this.getRoughOptions(element)

    switch (element.type) {
      case 'rectangle':
        this.renderRectangle(element, options)
        break
      case 'circle':
        this.renderCircle(element, options)
        break
      case 'line':
        this.renderLine(element, options)
        break
      case 'arrow':
        this.renderArrow(element, options)
        break
    }
  }

  private getRoughOptions(element: DrawboardElement): any {
    return {
      stroke: element.strokeColor,
      strokeWidth: element.strokeWidth,
      fill: element.backgroundColor === 'transparent' ? undefined : element.backgroundColor,
      fillStyle: element.fillStyle,
      strokeLineDash: this.getStrokeDashArray(element.strokeStyle, element.strokeWidth),
      roughness: element.roughness,
      seed: element.seed,
    }
  }

  private getStrokeDashArray(style: string, width: number): number[] | undefined {
    switch (style) {
      case 'dashed':
        return [width * 4, width * 2]
      case 'dotted':
        return [width, width]
      default:
        return undefined
    }
  }

  private renderRectangle(element: IDrawboardRectangleElement, options: any): void {
    this.rc.rectangle(element.x, element.y, element.width, element.height, options)
  }

  private renderCircle(element: IDrawboardCircleElement, options: any): void {
    const centerX = element.x + element.width / 2
    const centerY = element.y + element.height / 2
    this.rc.ellipse(centerX, centerY, Math.abs(element.width), Math.abs(element.height), options)
  }

  private renderLine(element: IDrawboardLineElement, options: any): void {
    if (element.points.length < 2) return

    const points = element.points.map(
      ([x, y]) => [element.x + x, element.y + y] as [number, number],
    )

    this.rc.linearPath(points, options)
  }

  private renderArrow(element: IDrawboardArrowElement, options: any): void {
    // Render the line part - arrow has same line properties except type
    if (element.points.length < 2) return

    const points = element.points.map(
      ([x, y]) => [element.x + x, element.y + y] as [number, number],
    )

    this.rc.linearPath(points, options)

    // Render arrowheads
    if (element.points.length >= 2) {
      const lastPoint = element.points[element.points.length - 1]
      const secondLastPoint = element.points[element.points.length - 2]

      if (element.endArrowhead === 'arrow') {
        this.renderArrowhead(
          element.x + secondLastPoint[0],
          element.y + secondLastPoint[1],
          element.x + lastPoint[0],
          element.y + lastPoint[1],
          element,
        )
      }

      if (element.startArrowhead === 'arrow' && element.points.length >= 2) {
        this.renderArrowhead(
          element.x + element.points[1][0],
          element.y + element.points[1][1],
          element.x + element.points[0][0],
          element.y + element.points[0][1],
          element,
        )
      }
    }
  }

  private renderArrowhead(
    x1: number,
    y1: number,
    x2: number,
    y2: number,
    element: DrawboardElement,
  ): void {
    const angle = Math.atan2(y2 - y1, x2 - x1)
    const arrowLength = 20
    const arrowAngle = Math.PI / 6 // 30 degrees

    this.context.save()
    this.context.strokeStyle = element.strokeColor
    this.context.lineWidth = element.strokeWidth

    this.context.beginPath()
    this.context.moveTo(x2, y2)
    this.context.lineTo(
      x2 - arrowLength * Math.cos(angle - arrowAngle),
      y2 - arrowLength * Math.sin(angle - arrowAngle),
    )
    this.context.moveTo(x2, y2)
    this.context.lineTo(
      x2 - arrowLength * Math.cos(angle + arrowAngle),
      y2 - arrowLength * Math.sin(angle + arrowAngle),
    )
    this.context.stroke()

    this.context.restore()
  }
}
