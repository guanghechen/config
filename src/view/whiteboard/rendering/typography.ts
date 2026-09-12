import {
  fitTextNode,
  hasText,
  textContent,
  textFont,
  textLineHeight,
  wrapText,
} from '@/shared/whiteboard/text'
import type { ITextElement, ITextKind, ITextLayout } from '@/shared/whiteboard/text'
import { labelArea, labelLayout } from '@/shared/whiteboard/geometry'
import { resizeNodeBox } from '@/shared/whiteboard/pose'
import type {
  IBounds,
  IElement,
  ILabelElement,
  INode,
  IWhiteboardDocument,
} from '@/shared/whiteboard/model'

// Each board owns its font measurements and derived layouts; no browser resources enter shared code.
export class BoardTypography {
  private canvas = document.createElement('canvas')
  private context = this.canvas.getContext('2d')!
  private font = ''
  private layouts = new Map<
    string,
    {
      text: string
      font: string
      kind: ITextKind
      lineHeight: number
      width: number
      height: number
      layout: ITextLayout
    }
  >()
  private sizes = new Map<
    string,
    { text: string; font: string; shape: string; width: number; height: number }
  >()

  private measure(text: string, element: ITextElement, kind: ITextKind): number {
    const font = textFont(element.style, kind)
    if (this.font !== font) {
      this.context.font = font
      this.font = font
    }
    return this.context.measureText(text).width
  }

  public layout = (element: ITextElement, width: number, height: number): ITextLayout => {
    const kind = element.type === 'text' ? 'text' : 'label'
    const font = textFont(element.style, kind),
      text = textContent(element)
    const lineHeight = textLineHeight(element.style, kind)
    const cached = this.layouts.get(element.id)
    if (
      cached?.font === font &&
      cached.kind === kind &&
      cached.text === text &&
      cached.width === width &&
      cached.height === height &&
      cached.lineHeight === lineHeight
    )
      return cached.layout
    const layout =
      kind === 'label' && !text.trim()
        ? { lines: [], width: 0, height: 0 }
        : wrapText(text, width, height, lineHeight, value => this.measure(value, element, kind))
    this.layouts.set(element.id, { text, font, kind, lineHeight, width, height, layout })
    return layout
  }

  public label = (element: ILabelElement, nodes: ReadonlyMap<string, IElement>) => {
    const area = labelArea(element, nodes),
      padding = element.type === 'edge' ? 8 : 0
    return labelLayout(
      element,
      nodes,
      this.layout(element, area.width - padding * 2, area.height - padding * 2),
    )
  }
  public labelBounds = (element: ILabelElement, nodes: ReadonlyMap<string, IElement>): IBounds =>
    this.label(element, nodes).bounds

  public normalize = (document: IWhiteboardDocument): IWhiteboardDocument => {
    let changed = false
    const ids = new Set<string>()
    const elements = document.elements.map(element => {
      ids.add(element.id)
      const previousLayout = this.layouts.get(element.id)
      if (previousLayout && (!hasText(element) || previousLayout.text !== textContent(element)))
        this.layouts.delete(element.id)
      if (
        (element.type !== 'text' && element.type !== 'shape') ||
        !element.autoSize ||
        (element.type === 'shape' && !element.label?.trim())
      ) {
        this.sizes.delete(element.id)
        return element
      }
      const kind = element.type === 'text' ? 'text' : 'label'
      const text = textContent(element),
        font = textFont(element.style, kind),
        shape = element.type === 'shape' ? element.shape : 'text'
      const cached = this.sizes.get(element.id)
      let fitted: INode
      if (cached?.text === text && cached.font === font && cached.shape === shape)
        fitted = resizeNodeBox(element, cached.width, cached.height)
      else {
        fitted = fitTextNode(element, value => this.measure(value, element, kind))
        this.sizes.set(element.id, {
          text,
          font,
          shape,
          width: fitted.width,
          height: fitted.height,
        })
      }
      changed ||= fitted !== element
      return fitted
    })
    for (const id of this.layouts.keys()) if (!ids.has(id)) this.layouts.delete(id)
    for (const id of this.sizes.keys()) if (!ids.has(id)) this.sizes.delete(id)
    return changed ? { ...document, elements } : document
  }

  public dispose = (): void => {
    this.layouts.clear()
    this.sizes.clear()
    this.font = ''
    this.canvas.width = this.canvas.height = 1
  }
}
