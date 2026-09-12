import type { IElement, IWhiteboardDocument } from './model.ts'
import { isThemeColor } from './colors.ts'

const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
const number = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 1e7
const text = (value: unknown): value is string =>
  typeof value === 'string' && value.length <= 2_000_000
const color = (value: unknown): boolean =>
  isThemeColor(value) || (typeof value === 'string' && /^(#[0-9a-f]{6}|transparent)$/i.test(value))
const choice = (value: unknown, choices: ReadonlyArray<string>): boolean =>
  typeof value === 'string' && choices.includes(value)

export function parseDocument(input: string): IWhiteboardDocument {
  if (input.length > 30_000_000) throw new Error('Whiteboard exceeds the 30 MB limit')
  const data: unknown = JSON.parse(input)
  if (
    !object(data) ||
    data.kind !== 'yoz.whiteboard' ||
    data.schemaVersion !== 1 ||
    !text(data.id) ||
    !data.id ||
    !text(data.title) ||
    (data.stacking !== undefined && data.stacking !== 'document') ||
    !Array.isArray(data.elements) ||
    data.elements.length > 50_000
  )
    throw new Error('Invalid whiteboard document or unsupported version')

  const ids = new Map<string, string>()
  const regionIds = new Set<string>()
  if (data.regions !== undefined) {
    if (!Array.isArray(data.regions) || data.regions.length > 1000)
      throw new Error('A whiteboard supports at most 1000 named areas')
    for (const region of data.regions) {
      if (
        !object(region) ||
        typeof region.id !== 'string' ||
        !region.id ||
        region.id.length > 128 ||
        regionIds.has(region.id) ||
        typeof region.name !== 'string' ||
        !region.name.trim() ||
        region.name.length > 256 ||
        !number(region.x) ||
        !number(region.y) ||
        !number(region.width) ||
        !number(region.height) ||
        region.width < 1 ||
        region.height < 1
      )
        throw new Error('Named areas need unique IDs, a name and valid bounds')
      regionIds.add(region.id)
    }
  }
  if (
    data.presentation !== undefined &&
    (!Array.isArray(data.presentation) ||
      data.presentation.length > 5000 ||
      data.presentation.some(id => typeof id !== 'string' || !regionIds.has(id)))
  )
    throw new Error('Presentation steps must reference existing named areas (at most 5000 steps)')
  for (const element of data.elements) {
    if (!object(element) || !text(element.id) || !element.id || ids.has(element.id)) {
      throw new Error('Elements must have unique, nonempty IDs')
    }
    const style = element.style
    if (
      (element.locked !== undefined && typeof element.locked !== 'boolean') ||
      (element.hidden !== undefined && typeof element.hidden !== 'boolean')
    )
      throw new Error(`Invalid element visibility or lock: ${element.id}`)
    if (
      (element.rotation !== undefined && (!number(element.rotation) || element.type === 'edge')) ||
      (element.flipX !== undefined &&
        (typeof element.flipX !== 'boolean' || element.type === 'edge')) ||
      (element.flipY !== undefined &&
        (typeof element.flipY !== 'boolean' || element.type === 'edge'))
    )
      throw new Error(`Invalid node transform: ${element.id}`)
    if (
      element.autoSize !== undefined &&
      (typeof element.autoSize !== 'boolean' ||
        (element.type !== 'text' && element.type !== 'shape'))
    )
      throw new Error(`Invalid automatic text size: ${element.id}`)
    if (
      element.groupId !== undefined &&
      (typeof element.groupId !== 'string' || !element.groupId || element.groupId.length > 128)
    ) {
      throw new Error(`Invalid group ID: ${element.id}`)
    }
    if (
      (element.type === 'shape' || element.type === 'edge') &&
      element.label !== undefined &&
      (!text(element.label) || element.label.length > 4000)
    ) {
      throw new Error(`Invalid element label: ${element.id}`)
    }
    if (
      !object(style) ||
      !color(style.stroke) ||
      !color(style.fill) ||
      (style.fontSize !== undefined &&
        (!number(style.fontSize) || style.fontSize < 8 || style.fontSize > 200)) ||
      (style.fontFamily !== undefined && !choice(style.fontFamily, ['hand', 'sans', 'mono'])) ||
      (style.fontWeight !== undefined && !choice(style.fontWeight, ['normal', 'bold'])) ||
      (style.textAlign !== undefined && !choice(style.textAlign, ['left', 'center', 'right'])) ||
      (style.fillPattern !== undefined &&
        (typeof style.fillPattern !== 'string' ||
          !['solid', 'hachure', 'cross-hatch'].includes(style.fillPattern))) ||
      !number(style.strokeWidth) ||
      style.strokeWidth < 0.5 ||
      style.strokeWidth > 12 ||
      !number(style.roughness) ||
      style.roughness < 0 ||
      style.roughness > 3
    ) {
      throw new Error(`Invalid style: ${element.id}`)
    }
    if (element.type === 'edge') {
      if (
        (element.routing !== undefined &&
          !choice(element.routing, ['straight', 'polyline', 'curve'])) ||
        (element.arrowStart !== undefined && !choice(element.arrowStart, ['none', 'arrow'])) ||
        (element.arrowEnd !== undefined && !choice(element.arrowEnd, ['none', 'arrow'])) ||
        (element.lineStyle !== undefined &&
          !choice(element.lineStyle, ['solid', 'dashed', 'dotted']))
      )
        throw new Error(`Invalid connector style: ${element.id}`)
      if (
        element.controls !== undefined &&
        (!Array.isArray(element.controls) ||
          element.controls.length > 64 ||
          ((element.routing === undefined || element.routing === 'straight') &&
            element.controls.length !== 0) ||
          (element.routing === 'curve' && element.controls.length !== 2) ||
          element.controls.some(point => !object(point) || !number(point.x) || !number(point.y)))
      )
        throw new Error(`Invalid connector controls: ${element.id}`)
      for (const endpoint of [element.from, element.to]) {
        if (
          !object(endpoint) ||
          !number(endpoint.x) ||
          !number(endpoint.y) ||
          (endpoint.nodeId !== undefined &&
            (!text(endpoint.nodeId) ||
              !endpoint.nodeId ||
              endpoint.x < 0 ||
              endpoint.x > 1 ||
              endpoint.y < 0 ||
              endpoint.y > 1))
        ) {
          throw new Error(`Invalid edge endpoint: ${element.id}`)
        }
      }
    } else {
      if (
        !number(element.x) ||
        !number(element.y) ||
        !number(element.width) ||
        !number(element.height) ||
        element.width < 1 ||
        element.height < 1
      ) {
        throw new Error(`Invalid node bounds: ${element.id}`)
      }
      switch (element.type) {
        case 'shape':
          if (!choice(element.shape, ['rectangle', 'ellipse', 'diamond'])) {
            throw new Error('Unknown shape')
          }
          break
        case 'text':
          if (!text(element.text)) throw new Error('Invalid text node')
          break
        case 'markdown': {
          const source = element.source
          if (
            !object(source) ||
            !(
              (source.kind === 'inline' && text(source.content)) ||
              (source.kind === 'file' &&
                text(source.filepath) &&
                source.filepath.startsWith('/') &&
                source.filepath.toLowerCase().endsWith('.md'))
            )
          ) {
            throw new Error('Markdown needs inline content or an absolute .md filepath')
          }
          break
        }
        case 'image':
          if (
            !text(element.url) ||
            !/^(https?:\/\/|\/|data:image\/(png|jpeg|webp|gif);base64,)/i.test(element.url)
          ) {
            throw new Error('Image needs an HTTP(S) URL, absolute path, or raster data URL')
          }
          break
        case 'stroke':
          if (
            !Array.isArray(element.points) ||
            element.points.length < 2 ||
            element.points.length > 100_000 ||
            element.points.some(
              point =>
                !object(point) ||
                !number(point.x) ||
                !number(point.y) ||
                point.x < 0 ||
                point.x > 1 ||
                point.y < 0 ||
                point.y > 1,
            )
          ) {
            throw new Error('Invalid freehand stroke')
          }
          break
        default:
          throw new Error('Unknown element type')
      }
    }
    ids.set(element.id, String(element.type))
  }
  for (const element of data.elements as IElement[]) {
    if (element.type !== 'edge') continue
    for (const endpoint of [element.from, element.to]) {
      if (endpoint.nodeId && (!ids.has(endpoint.nodeId) || ids.get(endpoint.nodeId) === 'edge')) {
        throw new Error(`Missing edge node: ${endpoint.nodeId}`)
      }
    }
  }
  return data as unknown as IWhiteboardDocument
}
