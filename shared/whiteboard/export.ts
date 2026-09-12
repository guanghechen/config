import { elementBounds, unionBounds } from './geometry.ts'
import type { IBounds, IElement, IWhiteboardDocument } from './model.ts'
import { hiddenElements } from './visibility.ts'

export function exportSelection(
  document: IWhiteboardDocument,
  selected?: ReadonlySet<string>,
): IElement[] {
  const hidden = hiddenElements(document.elements)
  const elements = document.elements.filter(
    element => !hidden.has(element.id) && (!selected || selected.has(element.id)),
  )
  if (!elements.length) throw new Error('There are no visible elements to export')
  return elements
}

export function exportBounds(
  elements: ReadonlyArray<IElement>,
  scene: ReadonlyArray<IElement>,
): IBounds {
  const map = new Map(scene.map(element => [element.id, element]))
  const bounds = unionBounds(elements.map(element => elementBounds(element, map)))
  if (!bounds) throw new Error('There are no visible elements to export')
  const padding = Math.max(
    24,
    ...elements.map(element => element.style.strokeWidth + element.style.roughness * 4 + 3),
  )
  return {
    x: bounds.x - padding,
    y: bounds.y - padding,
    width: bounds.width + padding * 2,
    height: bounds.height + padding * 2,
  }
}

export function rasterSize(bounds: IBounds, scale: number): { width: number; height: number } {
  const width = Math.ceil(bounds.width * scale),
    height = Math.ceil(bounds.height * scale)
  if (
    !Number.isFinite(scale) ||
    !Number.isFinite(width) ||
    !Number.isFinite(height) ||
    scale <= 0 ||
    width < 1 ||
    height < 1 ||
    width > 16384 ||
    height > 16384 ||
    width * height > 32_000_000
  )
    throw new Error(
      'PNG exceeds 32 megapixels or 16384 pixels per side. Reduce the scale, export a smaller selection, or choose SVG.',
    )
  return { width, height }
}
