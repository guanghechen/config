export interface IHighlightBounds {
  readonly x: number
  readonly y: number
  readonly width: number
  readonly height: number
}

export class HighlightOverlay {
  private element: HTMLDivElement | null = null
  private frame: number | null = null
  private target: Element | null = null
  private timer: number | null = null
  private readonly handleViewportChange = () => {
    if (this.frame !== null) return
    this.frame = window.requestAnimationFrame(() => {
      this.frame = null
      this.updateBounds()
    })
  }

  public show(target: Element, bounds: IHighlightBounds, durationMs: number): void {
    this.clear()
    const overlay = document.createElement('div')
    overlay.setAttribute('aria-hidden', 'true')
    overlay.style.cssText = [
      'position:fixed!important',
      'box-sizing:border-box!important',
      'border:2px solid #4daafc!important',
      'border-radius:4px!important',
      'background:rgba(77,170,252,.12)!important',
      'pointer-events:none!important',
      'z-index:2147483647!important',
    ].join(';')
    document.documentElement.appendChild(overlay)
    this.element = overlay
    this.target = target
    applyBounds(overlay, bounds)
    window.addEventListener('scroll', this.handleViewportChange, true)
    window.addEventListener('resize', this.handleViewportChange)
    this.timer = window.setTimeout(() => this.clear(), durationMs)
  }

  public dispose(): void {
    this.clear()
  }

  private clear(): void {
    if (this.timer !== null) window.clearTimeout(this.timer)
    if (this.frame !== null) window.cancelAnimationFrame(this.frame)
    window.removeEventListener('scroll', this.handleViewportChange, true)
    window.removeEventListener('resize', this.handleViewportChange)
    this.frame = null
    this.timer = null
    this.target = null
    this.element?.remove()
    this.element = null
  }

  private updateBounds(): void {
    const target = this.target
    const overlay = this.element
    if (!target || !overlay || !target.isConnected) {
      this.clear()
      return
    }
    const bounds = readBounds(target)
    if (bounds.width <= 0 || bounds.height <= 0) {
      this.clear()
      return
    }
    applyBounds(overlay, bounds)
  }
}

export function isBoundsInViewport(
  bounds: IHighlightBounds,
  viewportWidth = window.innerWidth,
  viewportHeight = window.innerHeight,
): boolean {
  return (
    bounds.x + bounds.width > 0 &&
    bounds.y + bounds.height > 0 &&
    bounds.x < viewportWidth &&
    bounds.y < viewportHeight
  )
}

function applyBounds(overlay: HTMLDivElement, bounds: IHighlightBounds): void {
  overlay.style.setProperty('left', `${bounds.x}px`, 'important')
  overlay.style.setProperty('top', `${bounds.y}px`, 'important')
  overlay.style.setProperty('width', `${bounds.width}px`, 'important')
  overlay.style.setProperty('height', `${bounds.height}px`, 'important')
}

function readBounds(element: Element): IHighlightBounds {
  const bounds = Element.prototype.getBoundingClientRect.call(element)
  return { x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height }
}
