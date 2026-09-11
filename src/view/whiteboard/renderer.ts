import {
  elementBounds,
  intersects,
  labelLayout,
  resolveEndpoint,
  unionBounds,
} from '@/shared/whiteboard/geometry'
import { sketchArrow, sketchShape, smoothStroke } from '@/shared/whiteboard/sketch'
import { LABEL_FONT, LABEL_LINE_HEIGHT } from '@/shared/whiteboard/labels'
import { RESIZE_CORNERS, resizeBounds } from '@/shared/whiteboard/transforms'
import { resolveStyle } from '@/shared/whiteboard/colors'
import type { IAlignmentGuide } from '@/shared/whiteboard/drawing'
import type { IWhiteboardTheme } from './theme'
import type {
  IBounds,
  ICamera,
  IElement,
  ILabelElement,
  INode,
  IPoint,
  IStyle,
} from '@/shared/whiteboard/model'

/* eslint-disable no-param-reassign -- The renderer owns and resizes its drawing surfaces. */

export function isCard(node: IElement): node is INode {
  return node.type === 'markdown' || node.type === 'image'
}

export function visibleBounds(
  camera: ICamera,
  width: number,
  height: number,
  margin = 100,
): IBounds {
  return {
    x: (-camera.x - margin) / camera.zoom,
    y: (-camera.y - margin) / camera.zoom,
    width: (width + margin * 2) / camera.zoom,
    height: (height + margin * 2) / camera.zoom,
  }
}

export class CanvasRenderer {
  private theme: IWhiteboardTheme
  private styles = new WeakMap<IStyle, { filled: IStyle; plain: IStyle; card: IStyle }>()

  constructor(theme: IWhiteboardTheme) {
    this.theme = theme
  }

  public setTheme(theme: IWhiteboardTheme): void {
    if (this.theme === theme) return
    this.theme = theme
    this.styles = new WeakMap()
    this.invalidate()
  }

  private style(element: IElement): IStyle {
    let resolved = this.styles.get(element.style)
    if (!resolved) {
      const plain = resolveStyle(element.style, this.theme.colors)
      resolved = {
        filled: resolveStyle(element.style, this.theme.colors, true),
        plain,
        card: { ...plain, fill: this.theme.paper },
      }
      this.styles.set(element.style, resolved)
    }
    return element.type === 'shape'
      ? resolved.filled
      : isCard(element)
        ? resolved.card
        : resolved.plain
  }
  private paths = new Map<
    string,
    {
      key: string
      outline: Path2D
      fill: Path2D
      hachure: Path2D
      points?: ReadonlyArray<IPoint>
    }
  >()
  private arrows = new Map<string, { key: string; path: Path2D }>()
  private bitmaps = new Map<
    string,
    { key: string; canvas: HTMLCanvasElement; scale: number; padding: number }
  >()
  private bitmapPixels = 0
  private cache: {
    elements: ReadonlyArray<IElement>
    camera: ICamera
    width: number
    height: number
    ratio: number
  } | null = null

  public invalidate(): void {
    this.cache = null
  }

  public dispose(): void {
    this.cache = null
    this.paths.clear()
    this.arrows.clear()
    for (const id of this.bitmaps.keys()) this.dropBitmap(id)
  }

  private dropBitmap(id: string): void {
    const bitmap = this.bitmaps.get(id)
    if (!bitmap) return
    this.bitmapPixels -= bitmap.canvas.width * bitmap.canvas.height
    bitmap.canvas.width = bitmap.canvas.height = 0
    this.bitmaps.delete(id)
  }

  public draw(
    canvas: HTMLCanvasElement,
    elements: ReadonlyArray<IElement>,
    camera: ICamera,
    width: number,
    height: number,
  ): void {
    // Keep readable text and shapes at the current scale; only the overview resamples its bitmap.
    if (camera.zoom >= 0.35) {
      this.cache = null
      canvas.style.width = `${width}px`
      canvas.style.height = `${height}px`
      canvas.style.transform = 'none'
      canvas.style.willChange = 'auto'
      this.drawScene(canvas, elements, camera, width, height)
      return
    }
    const ratio = window.devicePixelRatio || 1
    const previous = this.cache
    let scale = previous ? camera.zoom / previous.camera.zoom : 1
    let x = previous ? camera.x - previous.camera.x * scale : 0
    let y = previous ? camera.y - previous.camera.y * scale : 0
    // The overview benchmark spent 8–14 ms submitting the same paths each frame, plus raster work.
    // Reuse one overscanned raster while the immutable scene and visible detail level stay valid.
    if (
      !previous ||
      previous.elements !== elements ||
      previous.ratio !== ratio ||
      scale < 0.8 ||
      scale > 1.25 ||
      x > 0 ||
      y > 0 ||
      x + previous.width * scale < width ||
      y + previous.height * scale < height
    ) {
      const margin = 256
      const cacheCamera = { ...camera, x: camera.x + margin, y: camera.y + margin }
      this.drawScene(canvas, elements, cacheCamera, width + margin * 2, height + margin * 2)
      this.cache = {
        elements,
        camera: cacheCamera,
        width: width + margin * 2,
        height: height + margin * 2,
        ratio,
      }
      scale = 1
      x = -margin
      y = -margin
    }
    canvas.style.width = `${this.cache!.width}px`
    canvas.style.height = `${this.cache!.height}px`
    canvas.style.transform = `translate(${x}px, ${y}px) scale(${scale})`
    canvas.style.willChange = 'transform'
  }

  private path(node: INode, patterns: boolean) {
    const key = `${node.width},${node.height},${node.style.roughness},${patterns ? node.style.fillPattern : 'solid'},${node.type === 'shape' ? node.shape : node.type}`
    const points = node.type === 'stroke' ? node.points : undefined
    const cached = this.paths.get(node.id)
    if (cached?.key === key && cached.points === points) return cached
    const paths =
      node.type === 'stroke'
        ? { outline: smoothStroke(node.points, node.width, node.height), fill: '', hachure: '' }
        : sketchShape(
            node.id,
            node.width,
            node.height,
            node.type === 'shape' ? node.shape : 'rectangle',
            node.style.roughness,
            patterns ? node.style.fillPattern : 'solid',
          )
    const result = {
      key,
      points,
      outline: new Path2D(paths.outline),
      fill: new Path2D(paths.fill),
      hachure: new Path2D(paths.hachure),
    }
    this.paths.set(node.id, result)
    return result
  }

  private paintShape(ctx: CanvasRenderingContext2D, node: INode, patterns: boolean): void {
    const paths = this.path(node, patterns)
    if (node.type !== 'stroke') {
      if (patterns && node.style.fillPattern && node.style.fillPattern !== 'solid') {
        ctx.save()
        ctx.clip(paths.fill)
        ctx.strokeStyle = this.style(node).fill
        ctx.lineWidth = Math.max(0.8, node.style.strokeWidth * 0.6)
        ctx.stroke(paths.hachure)
        ctx.restore()
      } else ctx.fill(paths.fill)
    }
    ctx.stroke(paths.outline)
  }

  private bitmap(node: INode, resolution: number) {
    const style = this.style(node)
    const key = `${node.width},${node.height},${node.type === 'shape' ? node.shape : node.type},${style.roughness},${style.strokeWidth},${style.stroke},${style.fill},${style.fillPattern}`
    const scale = Math.max(1, 2 ** Math.ceil(Math.log2(resolution) - 1e-6))
    const previous = this.bitmaps.get(node.id)
    if (previous?.key === key && previous.scale >= scale) {
      this.bitmaps.delete(node.id)
      this.bitmaps.set(node.id, previous)
      return previous
    }
    const padding = Math.ceil(node.style.roughness * 4 + node.style.strokeWidth + 2)
    const width = Math.ceil((node.width + padding * 2) * scale)
    const height = Math.ceil((node.height + padding * 2) * scale)
    // Keep at most 16 MiB of shape pixels; very large / highly zoomed shapes stay vector-drawn.
    if (width > 2048 || height > 2048 || width * height > 1_048_576) return null
    const canvas = previous?.canvas ?? document.createElement('canvas')
    this.dropBitmap(node.id)
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')!
    ctx.scale(scale, scale)
    ctx.translate(padding, padding)
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.strokeStyle = style.stroke
    ctx.fillStyle = style.fill
    ctx.lineWidth = node.style.strokeWidth
    this.paintShape(ctx, node, true)
    const bitmap = { key, canvas, scale, padding }
    this.bitmaps.set(node.id, bitmap)
    this.bitmapPixels += width * height
    while (this.bitmapPixels > 4_194_304) this.dropBitmap(this.bitmaps.keys().next().value!)
    return bitmap
  }

  private drawScene(
    canvas: HTMLCanvasElement,
    elements: ReadonlyArray<IElement>,
    camera: ICamera,
    width: number,
    height: number,
  ): void {
    const ratio = window.devicePixelRatio || 1
    if (
      canvas.width !== Math.round(width * ratio) ||
      canvas.height !== Math.round(height * ratio)
    ) {
      canvas.width = Math.round(width * ratio)
      canvas.height = Math.round(height * ratio)
    }
    const ctx = canvas.getContext('2d')!
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, width, height)
    ctx.translate(camera.x, camera.y)
    ctx.scale(camera.zoom, camera.zoom)
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    const map = new Map(elements.map(element => [element.id, element]))
    for (const id of this.paths.keys()) if (!map.has(id)) this.paths.delete(id)
    for (const id of this.arrows.keys()) if (!map.has(id)) this.arrows.delete(id)
    for (const id of this.bitmaps.keys()) if (map.get(id)?.type !== 'shape') this.dropBitmap(id)
    const visible = visibleBounds(camera, width, height)
    for (const element of elements) {
      if (element.type !== 'edge' || !intersects(elementBounds(element, map), visible)) continue
      const a = resolveEndpoint(element.from, map),
        b = resolveEndpoint(element.to, map)
      ctx.strokeStyle = this.style(element).stroke
      ctx.fillStyle = this.style(element).stroke
      ctx.lineWidth = element.style.strokeWidth
      const delta = { x: b.x - a.x, y: b.y - a.y }
      const key = `${delta.x},${delta.y},${element.style.roughness},${element.style.strokeWidth}`
      let arrow = this.arrows.get(element.id)
      if (arrow?.key !== key) {
        arrow = {
          key,
          path: new Path2D(
            sketchArrow(element.id, delta, element.style.roughness, element.style.strokeWidth),
          ),
        }
        this.arrows.set(element.id, arrow)
      }
      ctx.save()
      ctx.translate(a.x, a.y)
      ctx.stroke(arrow.path)
      ctx.restore()
      if (element.label) this.drawLabel(ctx, element, map)
    }
    for (const element of elements) {
      if (element.type === 'edge' || !intersects(element, visible)) continue
      if (isCard(element) && camera.zoom >= 0.35) continue
      ctx.save()
      ctx.translate(element.x, element.y)
      ctx.strokeStyle = this.style(element).stroke
      ctx.fillStyle = this.style(element).fill
      ctx.lineWidth = element.style.strokeWidth
      if (element.type === 'text') {
        ctx.fillStyle = this.style(element).stroke
        ctx.font = '24px "Comic Sans MS", "Segoe Print", cursive'
        ctx.beginPath()
        ctx.rect(0, 0, element.width, element.height)
        ctx.clip()
        let line = '',
          y = 28
        for (const paragraph of element.text.split('\n')) {
          for (const word of paragraph.split(' ')) {
            if (line && ctx.measureText(`${line} ${word}`).width > element.width) {
              ctx.fillText(line, 0, y)
              line = ''
              y += 32
            }
            line += `${line ? ' ' : ''}${word}`
          }
          ctx.fillText(line, 0, y)
          line = ''
          y += 32
        }
      } else {
        const patterns = camera.zoom >= 0.35
        const bitmap =
          element.type === 'shape' && patterns ? this.bitmap(element, camera.zoom * ratio) : null
        if (bitmap)
          ctx.drawImage(
            bitmap.canvas,
            -bitmap.padding,
            -bitmap.padding,
            bitmap.canvas.width / bitmap.scale,
            bitmap.canvas.height / bitmap.scale,
          )
        else this.paintShape(ctx, element, patterns)
        if (isCard(element)) {
          ctx.fillStyle = this.theme.ink
          ctx.font = '24px sans-serif'
          const title =
            element.type === 'markdown'
              ? element.source.kind === 'file'
                ? element.source.filepath.split('/').pop()!
                : element.source.content
                    .split('\n')
                    .find(Boolean)
                    ?.replace(/^#+\s*/, '') || 'Markdown'
              : 'Image'
          ctx.fillText(title.slice(0, 45), 16, 36, Math.max(1, element.width - 32))
          ctx.fillStyle = this.theme.border
          for (let i = 0; i < 3; i++)
            ctx.fillRect(16, 65 + i * 20, Math.max(1, element.width - 32 - i * 25), 5)
        }
      }
      ctx.restore()
      if (element.type === 'shape' && element.label) this.drawLabel(ctx, element, map)
    }
    // Selection is drawn on a separate overlay canvas by drawSelection.
  }

  private drawLabel(
    ctx: CanvasRenderingContext2D,
    element: ILabelElement,
    nodes: ReadonlyMap<string, IElement>,
  ): void {
    const { lines, bounds } = labelLayout(element, nodes)
    if (!lines.length) return
    ctx.save()
    if (element.type === 'edge') {
      ctx.fillStyle = this.theme.canvas
      ctx.fillRect(bounds.x, bounds.y, bounds.width, bounds.height)
    }
    ctx.fillStyle = this.style(element).stroke
    ctx.font = LABEL_FONT
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    const padding = element.type === 'edge' ? 8 : 0
    lines.forEach((line, index) =>
      ctx.fillText(
        line,
        bounds.x + bounds.width / 2,
        bounds.y + padding + (index + 0.5) * LABEL_LINE_HEIGHT,
        Math.max(1, bounds.width - padding * 2),
      ),
    )
    ctx.restore()
  }

  public drawSelection(
    canvas: HTMLCanvasElement,
    elements: ReadonlyArray<IElement>,
    camera: ICamera,
    selected: ReadonlySet<string>,
    width: number,
    height: number,
    marquee?: IBounds,
    guides: ReadonlyArray<IAlignmentGuide> = [],
  ): void {
    if (!selected.size && !marquee && !guides.length) {
      canvas.style.display = 'none'
      return
    }
    canvas.style.display = 'block'
    const ratio = window.devicePixelRatio || 1
    if (
      canvas.width !== Math.round(width * ratio) ||
      canvas.height !== Math.round(height * ratio)
    ) {
      canvas.width = Math.round(width * ratio)
      canvas.height = Math.round(height * ratio)
    }
    const ctx = canvas.getContext('2d')!
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    ctx.setTransform(
      ratio * camera.zoom,
      0,
      0,
      ratio * camera.zoom,
      ratio * camera.x,
      ratio * camera.y,
    )
    ctx.strokeStyle = this.theme.selection
    ctx.lineWidth = 1.5 / camera.zoom
    const map = new Map(elements.map(element => [element.id, element]))
    const groups = new Map<string, IBounds[]>()
    for (const element of elements) {
      if (!selected.has(element.id)) continue
      const bounds = elementBounds(element, map)
      if (element.groupId) {
        const group = groups.get(element.groupId)
        if (group) group.push(bounds)
        else groups.set(element.groupId, [bounds])
      }
      ctx.strokeRect(
        bounds.x - 4 / camera.zoom,
        bounds.y - 4 / camera.zoom,
        bounds.width + 8 / camera.zoom,
        bounds.height + 8 / camera.zoom,
      )
      if (selected.size === 1 && element.type === 'edge') {
        ctx.fillStyle = this.theme.paper
        for (const end of [element.from, element.to]) {
          const point = resolveEndpoint(end, map)
          ctx.beginPath()
          ctx.arc(point.x, point.y, 6 / camera.zoom, 0, Math.PI * 2)
          ctx.fill()
          ctx.stroke()
        }
      }
    }
    ctx.setLineDash([6 / camera.zoom, 4 / camera.zoom])
    for (const group of groups.values()) {
      if (group.length < 2) continue
      const bounds = unionBounds(group)!
      const padding = 10 / camera.zoom
      ctx.strokeRect(
        bounds.x - padding,
        bounds.y - padding,
        bounds.width + padding * 2,
        bounds.height + padding * 2,
      )
    }
    ctx.setLineDash([])
    const selection = resizeBounds(elements, selected)
    if (selection) {
      if (selected.size > 1) {
        const padding = 4 / camera.zoom
        ctx.strokeRect(
          selection.x - padding,
          selection.y - padding,
          selection.width + padding * 2,
          selection.height + padding * 2,
        )
      }
      const size = 8 / camera.zoom
      ctx.fillStyle = this.theme.paper
      for (const corner of RESIZE_CORNERS) {
        const x = selection.x + corner.x * selection.width - size / 2
        const y = selection.y + corner.y * selection.height - size / 2
        ctx.fillRect(x, y, size, size)
        ctx.strokeRect(x, y, size, size)
      }
    }
    if (marquee) {
      ctx.fillStyle = this.theme.selection
      ctx.globalAlpha = 0.12
      ctx.fillRect(marquee.x, marquee.y, marquee.width, marquee.height)
      ctx.globalAlpha = 1
      ctx.strokeRect(marquee.x, marquee.y, marquee.width, marquee.height)
    }
    ctx.lineWidth = 1 / camera.zoom
    ctx.setLineDash([4 / camera.zoom, 4 / camera.zoom])
    for (const guide of guides) {
      const padding = 10 / camera.zoom
      ctx.beginPath()
      if (guide.axis === 'x') {
        ctx.moveTo(guide.position, guide.from - padding)
        ctx.lineTo(guide.position, guide.to + padding)
      } else {
        ctx.moveTo(guide.from - padding, guide.position)
        ctx.lineTo(guide.to + padding, guide.position)
      }
      ctx.stroke()
    }
    ctx.setLineDash([])
  }
}
