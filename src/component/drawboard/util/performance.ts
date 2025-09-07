import React from 'react'

interface IPerformanceMetrics {
  readonly frameRate: number
  readonly renderTime: number
  readonly frameCount: number
}

interface IRenderTask {
  readonly id: string
  readonly callback: () => void
  readonly priority: number
}

interface IPerformanceMonitor {
  readonly metrics: IPerformanceMetrics
  readonly isEnabled: boolean
  onMetricsUpdate?: (metrics: IPerformanceMetrics) => void
}

class PerformanceManager {
  private renderTasks = new Map<string, IRenderTask>()
  private isRendering = false
  private rafId: number | null = null
  private frameCount = 0
  private lastFrameTime = 0
  private frameStartTime = 0
  private renderTimes: number[] = []
  private frameRates: number[] = []
  private monitor: IPerformanceMonitor = {
    metrics: { frameRate: 0, renderTime: 0, frameCount: 0 },
    isEnabled: false,
  }

  public setPerformanceMonitoring(
    enabled: boolean,
    callback?: (metrics: IPerformanceMetrics) => void,
  ): void {
    this.monitor = {
      ...this.monitor,
      isEnabled: enabled,
      onMetricsUpdate: callback,
    }
  }

  public scheduleRender(id: string, callback: () => void, priority = 0): void {
    this.renderTasks.set(id, { id, callback, priority })
    this.requestRender()
  }

  public cancelRender(id: string): void {
    this.renderTasks.delete(id)
  }

  public debounceRender(id: string, callback: () => void, delay = 16): void {
    this.cancelRender(id)
    setTimeout(() => {
      this.scheduleRender(id, callback)
    }, delay)
  }

  private requestRender(): void {
    if (this.isRendering) return

    this.isRendering = true
    this.rafId = requestAnimationFrame(this.render)
  }

  private render = (): void => {
    this.frameStartTime = performance.now()

    if (this.monitor.isEnabled) {
      this.updateFrameRate()
    }

    try {
      // Sort tasks by priority (higher priority first)
      const tasks = Array.from(this.renderTasks.values()).sort((a, b) => b.priority - a.priority)

      // Execute all render tasks
      for (const task of tasks) {
        try {
          task.callback()
        } catch (error) {
          console.warn(`Render task ${task.id} failed:`, error)
        }
      }

      // Clear completed tasks
      this.renderTasks.clear()
    } finally {
      this.isRendering = false

      if (this.monitor.isEnabled) {
        this.updateRenderTime()
        this.updateMetrics()
      }
    }
  }

  private updateFrameRate(): void {
    const currentTime = this.frameStartTime
    if (this.lastFrameTime > 0) {
      const deltaTime = currentTime - this.lastFrameTime
      const fps = 1000 / deltaTime
      this.frameRates.push(fps)

      // Keep only last 60 frame rates for average
      if (this.frameRates.length > 60) {
        this.frameRates.shift()
      }
    }
    this.lastFrameTime = currentTime
    this.frameCount++
  }

  private updateRenderTime(): void {
    const renderTime = performance.now() - this.frameStartTime
    this.renderTimes.push(renderTime)

    // Keep only last 60 render times for average
    if (this.renderTimes.length > 60) {
      this.renderTimes.shift()
    }
  }

  private updateMetrics(): void {
    const avgFrameRate =
      this.frameRates.length > 0
        ? this.frameRates.reduce((sum, fps) => sum + fps, 0) / this.frameRates.length
        : 0

    const avgRenderTime =
      this.renderTimes.length > 0
        ? this.renderTimes.reduce((sum, time) => sum + time, 0) / this.renderTimes.length
        : 0

    this.monitor = {
      ...this.monitor,
      metrics: {
        frameRate: Math.round(avgFrameRate),
        renderTime: Math.round(avgRenderTime * 100) / 100,
        frameCount: this.frameCount,
      },
    }

    if (this.monitor.onMetricsUpdate) {
      this.monitor.onMetricsUpdate(this.monitor.metrics)
    }
  }

  public getMetrics(): IPerformanceMetrics {
    return this.monitor.metrics
  }

  public destroy(): void {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
    this.renderTasks.clear()
    this.isRendering = false
  }
}

// Global performance manager instance
export const performanceManager = new PerformanceManager()

// Convenience hooks and utilities
export const useRafRender = (
  id: string,
  callback: () => void,
  deps: React.DependencyList,
): void => {
  React.useEffect(() => {
    performanceManager.scheduleRender(id, callback)
  }, deps)

  React.useEffect(() => {
    return () => performanceManager.cancelRender(id)
  }, [id])
}

export const useDebouncedRender = (
  id: string,
  callback: () => void,
  deps: React.DependencyList,
  delay = 16,
): void => {
  React.useEffect(() => {
    performanceManager.debounceRender(id, callback, delay)
  }, deps)

  React.useEffect(() => {
    return () => performanceManager.cancelRender(id)
  }, [id])
}

export const usePerformanceMetrics = (enabled = true): IPerformanceMetrics => {
  const [metrics, setMetrics] = React.useState<IPerformanceMetrics>({
    frameRate: 0,
    renderTime: 0,
    frameCount: 0,
  })

  React.useEffect(() => {
    performanceManager.setPerformanceMonitoring(enabled, setMetrics)
    return () => performanceManager.setPerformanceMonitoring(false)
  }, [enabled])

  return metrics
}

// Grid rendering optimization utilities
export interface IGridCache {
  readonly canvas: OffscreenCanvas | HTMLCanvasElement
  readonly lastParams: string
  readonly timestamp: number
}

export class GridCacheManager {
  private cache = new Map<string, IGridCache>()
  private readonly maxCacheSize = 25 // Increased for zoom level caching
  private readonly cacheTimeout = 60000 // Increased to 60 seconds for better reuse
  private usageStats = new Map<string, number>() // Track cache usage for intelligent eviction
  private precomputedPatterns = new Map<string, OffscreenCanvas>() // Common zoom patterns

  // Common zoom levels to precompute for performance
  private readonly commonZoomLevels = [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0]

  constructor() {
    // Precompute common patterns on next tick to avoid blocking initialization
    setTimeout(() => this.precomputeCommonPatterns(), 100)
  }

  private precomputeCommonPatterns(): void {
    try {
      // Precompute patterns for common grid sizes at different zoom levels
      const baseGridSize = 20 // Standard grid size
      const standardDimensions = { width: 800, height: 600 } // Standard canvas size

      for (const zoom of this.commonZoomLevels) {
        const scaledGridSize = baseGridSize * zoom
        if (scaledGridSize >= 2) {
          // Only precompute visible grids
          const patternKey = `pattern_${scaledGridSize.toFixed(1)}`
          this.precomputePattern(patternKey, baseGridSize, zoom, standardDimensions)
        }
      }
    } catch (error) {
      console.warn('Grid pattern precomputation failed:', error)
    }
  }

  private precomputePattern(
    patternKey: string,
    gridSize: number,
    zoom: number,
    dimensions: { width: number; height: number },
  ): void {
    try {
      const offscreenCanvas = new OffscreenCanvas(dimensions.width, dimensions.height)
      const ctx = offscreenCanvas.getContext('2d')
      if (!ctx) return

      // Use standard light theme for precomputation
      const theme = {
        minorGridColor: '#d8d8d8',
        majorGridColor: '#d8d8d8',
        minorLineWidth: 0.5,
        majorLineWidth: 1,
        opacity: 1,
      }

      // Draw a clean grid pattern centered at origin
      this.drawPrecomputedGridPattern(ctx, gridSize, zoom, dimensions, theme)
      this.precomputedPatterns.set(patternKey, offscreenCanvas)
    } catch (error) {
      console.warn(`Pattern precomputation failed for ${patternKey}:`, error)
    }
  }

  private drawPrecomputedGridPattern(
    ctx: CanvasRenderingContext2D | OffscreenCanvasRenderingContext2D,
    gridSize: number,
    zoom: number,
    dimensions: { width: number; height: number },
    theme: any,
  ): void {
    const scaledGridSize = gridSize * zoom
    const { width, height } = dimensions

    const renderingCtx = ctx
    renderingCtx.save()
    renderingCtx.globalAlpha = theme.opacity

    const drawLines = (isVertical: boolean, isMajor: boolean): void => {
      const dimension = isVertical ? width : height
      const lineWidth = isMajor ? theme.majorLineWidth : theme.minorLineWidth
      const strokeStyle = isMajor ? theme.majorGridColor : theme.minorGridColor
      const interval = isMajor ? scaledGridSize * 5 : scaledGridSize

      if (!isMajor && scaledGridSize < 8) return // Skip minor lines when too small

      renderingCtx.lineWidth = lineWidth
      renderingCtx.strokeStyle = strokeStyle
      renderingCtx.setLineDash(isMajor ? [] : [3, 3])
      renderingCtx.beginPath()

      for (let pos = 0; pos < dimension; pos += interval) {
        if (isVertical) {
          renderingCtx.moveTo(pos, 0)
          renderingCtx.lineTo(pos, height)
        } else {
          renderingCtx.moveTo(0, pos)
          renderingCtx.lineTo(width, pos)
        }
      }

      renderingCtx.stroke()
    }

    // Draw major lines first, then minor lines
    drawLines(true, true) // Vertical major
    drawLines(false, true) // Horizontal major
    drawLines(true, false) // Vertical minor
    drawLines(false, false) // Horizontal minor

    renderingCtx.restore()
  }

  public getPrecomputedPattern(gridSize: number, zoom: number): OffscreenCanvas | null {
    const scaledGridSize = gridSize * zoom
    const patternKey = `pattern_${scaledGridSize.toFixed(1)}`
    return this.precomputedPatterns.get(patternKey) || null
  }

  public getFromCache(cacheKey: string): IGridCache | null {
    const cached = this.cache.get(cacheKey)
    if (!cached) return null

    // Check if cache is still valid
    if (Date.now() - cached.timestamp > this.cacheTimeout) {
      this.cache.delete(cacheKey)
      this.usageStats.delete(cacheKey)
      return null
    }

    // Track usage for intelligent eviction
    const currentUsage = this.usageStats.get(cacheKey) || 0
    this.usageStats.set(cacheKey, currentUsage + 1)

    return cached
  }

  public setCache(
    cacheKey: string,
    canvas: OffscreenCanvas | HTMLCanvasElement,
    params: string,
  ): void {
    // Clean old cache entries if we exceed max size using LFU eviction
    if (this.cache.size >= this.maxCacheSize) {
      this.evictLeastUsed()
    }

    this.cache.set(cacheKey, {
      canvas,
      lastParams: params,
      timestamp: Date.now(),
    })

    // Initialize usage stats
    this.usageStats.set(cacheKey, 1)
  }

  private evictLeastUsed(): void {
    let leastUsedKey: string | null = null
    let minUsage = Infinity

    for (const [key, usage] of this.usageStats.entries()) {
      if (usage < minUsage) {
        minUsage = usage
        leastUsedKey = key
      }
    }

    if (leastUsedKey) {
      this.cache.delete(leastUsedKey)
      this.usageStats.delete(leastUsedKey)
    }
  }

  public clear(): void {
    this.cache.clear()
    this.usageStats.clear()
    // Keep precomputed patterns as they're expensive to regenerate
  }

  public getCacheStats(): { size: number; maxSize: number; hitRate: number } {
    const totalUsage = Array.from(this.usageStats.values()).reduce((sum, usage) => sum + usage, 0)
    const totalQueries = totalUsage || 1 // Avoid division by zero

    return {
      size: this.cache.size,
      maxSize: this.maxCacheSize,
      hitRate: Math.round((totalUsage / totalQueries) * 100) / 100,
    }
  }
}

// Gesture batching utilities for smooth pointer interactions
export interface IBatchedGesture {
  readonly id: string
  readonly type: 'pan' | 'draw' | 'zoom'
  readonly events: PointerEvent[]
  readonly lastProcessed: number
}

class GestureBatchManager {
  private batches = new Map<string, IBatchedGesture>()
  // eslint-disable-next-line func-call-spacing
  private processingCallbacks = new Map<string, (batch: IBatchedGesture) => void>()
  private rafId: number | null = null
  private readonly maxBatchTime = 16 // 60fps
  private readonly maxBatchSize = 10

  public addGestureEvent(
    id: string,
    type: 'pan' | 'draw' | 'zoom',
    event: PointerEvent,
    callback: (batch: IBatchedGesture) => void,
  ): void {
    const now = performance.now()

    // Get existing batch or create new one
    const existingBatch = this.batches.get(id)
    const events = existingBatch ? [...existingBatch.events] : []
    events.push(event)

    // Limit batch size to prevent memory issues
    if (events.length > this.maxBatchSize) {
      events.shift()
    }

    const batch: IBatchedGesture = {
      id,
      type,
      events,
      lastProcessed: existingBatch?.lastProcessed || now,
    }

    this.batches.set(id, batch)
    this.processingCallbacks.set(id, callback)

    // Schedule processing if not already scheduled
    if (!this.rafId) {
      this.rafId = requestAnimationFrame(this.processBatches)
    }
  }

  public cancelGesture(id: string): void {
    this.batches.delete(id)
    this.processingCallbacks.delete(id)
  }

  private processBatches = (): void => {
    const now = performance.now()
    this.rafId = null

    // Process batches that are ready (based on time elapsed)
    for (const [id, batch] of this.batches.entries()) {
      const timeSinceLastProcess = now - batch.lastProcessed

      if (timeSinceLastProcess >= this.maxBatchTime || batch.events.length >= this.maxBatchSize) {
        const callback = this.processingCallbacks.get(id)
        if (callback) {
          try {
            callback(batch)
            // Update last processed time
            this.batches.set(id, { ...batch, lastProcessed: now })
          } catch (error) {
            console.warn(`Gesture batch processing failed for ${id}:`, error)
          }
        }
      }
    }

    // Schedule next processing if there are still batches
    if (this.batches.size > 0) {
      this.rafId = requestAnimationFrame(this.processBatches)
    }

    this.lastProcessTime = now
  }

  public destroy(): void {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
    this.batches.clear()
    this.processingCallbacks.clear()
  }
}

export const gestureBatchManager = new GestureBatchManager()

// Global grid cache manager instance
export const gridCacheManager = new GridCacheManager()

// Hardware-accelerated animation utilities for smooth transitions
export interface IAnimationFrame {
  readonly id: string
  readonly startTime: number
  readonly duration: number
  readonly from: number
  readonly to: number
  readonly easing: (t: number) => number
  readonly onUpdate: (value: number) => void
  readonly onComplete?: () => void
}

class AnimationFrameManager {
  private animations = new Map<string, IAnimationFrame>()
  private rafId: number | null = null

  public animate(
    id: string,
    from: number,
    to: number,
    duration: number,
    easing: (t: number) => number,
    onUpdate: (value: number) => void,
    onComplete?: () => void,
  ): void {
    // Cancel existing animation with same ID
    this.cancelAnimation(id)

    const animation: IAnimationFrame = {
      id,
      startTime: performance.now(),
      duration,
      from,
      to,
      easing,
      onUpdate,
      onComplete,
    }

    this.animations.set(id, animation)

    if (!this.rafId) {
      this.rafId = requestAnimationFrame(this.processAnimations)
    }
  }

  public cancelAnimation(id: string): void {
    this.animations.delete(id)
  }

  private processAnimations = (): void => {
    const now = performance.now()
    this.rafId = null

    const toRemove: string[] = []

    for (const [id, animation] of this.animations.entries()) {
      const elapsed = now - animation.startTime
      const progress = Math.min(elapsed / animation.duration, 1)
      const easedProgress = animation.easing(progress)
      const currentValue = animation.from + (animation.to - animation.from) * easedProgress

      try {
        animation.onUpdate(currentValue)
      } catch (error) {
        console.warn(`Animation ${id} update failed:`, error)
      }

      if (progress >= 1) {
        toRemove.push(id)
        if (animation.onComplete) {
          try {
            animation.onComplete()
          } catch (error) {
            console.warn(`Animation ${id} completion callback failed:`, error)
          }
        }
      }
    }

    // Remove completed animations
    toRemove.forEach(id => this.animations.delete(id))

    // Continue animation loop if there are still animations
    if (this.animations.size > 0) {
      this.rafId = requestAnimationFrame(this.processAnimations)
    }
  }

  public destroy(): void {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
    this.animations.clear()
  }
}

export const animationFrameManager = new AnimationFrameManager()

// Easing functions for smooth animations
export const easingFunctions = {
  linear: (t: number): number => t,
  easeOut: (t: number): number => 1 - Math.pow(1 - t, 3),
  easeInOut: (t: number): number => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  easeOutQuart: (t: number): number => 1 - Math.pow(1 - t, 4),
  bounce: (t: number): number => {
    const n1 = 7.5625
    const d1 = 2.75
    let t1 = t
    if (t1 < 1 / d1) {
      return n1 * t1 * t1
    } else if (t1 < 2 / d1) {
      t1 -= 1.5 / d1
      return n1 * t1 * t1 + 0.75
    } else if (t1 < 2.5 / d1) {
      t1 -= 2.25 / d1
      return n1 * t1 * t1 + 0.9375
    } else {
      t1 -= 2.625 / d1
      return n1 * t1 * t1 + 0.984375
    }
  },
}
