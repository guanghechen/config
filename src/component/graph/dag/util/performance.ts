import type { IGraphNode, ITransform } from '../types'

export const isNodeInViewport = (
  node: IGraphNode,
  transform: ITransform,
  canvasWidth: number,
  canvasHeight: number,
  padding: number = 100,
): boolean => {
  if (!node.position) return false

  const { x, y } = node.position
  const { width, height } = node.size || { width: 120, height: 60 }

  const screenX = x * transform.scale + transform.x
  const screenY = y * transform.scale + transform.y
  const screenWidth = width * transform.scale
  const screenHeight = height * transform.scale

  return (
    screenX + screenWidth >= -padding &&
    screenX <= canvasWidth + padding &&
    screenY + screenHeight >= -padding &&
    screenY <= canvasHeight + padding
  )
}

export const shouldUseDetailedRendering = (transform: ITransform): boolean => {
  return transform.scale >= 0.5
}

export class PerformanceMonitor {
  private frameCount = 0
  private lastTime = 0
  private fps = 0
  private renderTimes: number[] = []

  public startFrame(): number {
    return performance.now()
  }

  public endFrame(startTime: number): void {
    const endTime = performance.now()
    const renderTime = endTime - startTime

    this.renderTimes.push(renderTime)
    if (this.renderTimes.length > 60) {
      this.renderTimes.shift()
    }

    this.frameCount++
    if (endTime - this.lastTime >= 1000) {
      this.fps = this.frameCount
      this.frameCount = 0
      this.lastTime = endTime
    }
  }

  public getFPS(): number {
    return this.fps
  }

  public getAverageRenderTime(): number {
    if (this.renderTimes.length === 0) return 0
    return this.renderTimes.reduce((sum, time) => sum + time, 0) / this.renderTimes.length
  }

  public shouldSkipFrame(): boolean {
    return this.getAverageRenderTime() > 16.67
  }
}
