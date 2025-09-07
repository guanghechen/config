import type { IDrawboardElement } from '../types/elements'

export interface IExportOptions {
  backgroundColor?: string
  padding?: number
  scale?: number
}

export async function exportToPNG(
  elements: IDrawboardElement[],
  options: IExportOptions = {},
): Promise<Blob> {
  const { backgroundColor = '#ffffff', padding = 20, scale = 2 } = options

  // Calculate bounds
  const bounds = calculateBounds(elements)
  const width = (bounds.maxX - bounds.minX + padding * 2) * scale
  const height = (bounds.maxY - bounds.minY + padding * 2) * scale

  // Create offscreen canvas
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')!

  // Set background
  ctx.fillStyle = backgroundColor
  ctx.fillRect(0, 0, width, height)

  // Apply transformations
  ctx.scale(scale, scale)
  ctx.translate(-bounds.minX + padding, -bounds.minY + padding)

  // Render elements
  const { RoughRenderer } = await import('../renderer/RoughRenderer')
  const renderer = new RoughRenderer(canvas)
  elements.forEach(element => {
    if (!element.isDeleted) {
      try {
        renderer.renderElement(element)
      } catch (error) {
        console.warn('Failed to render element for export:', element.id, error)
      }
    }
  })

  // Convert to blob
  return new Promise((resolve, reject) => {
    canvas.toBlob(blob => {
      if (blob) {
        resolve(blob)
      } else {
        reject(new Error('Failed to create blob'))
      }
    }, 'image/png')
  })
}

export function exportToJSON(elements: IDrawboardElement[]): string {
  return JSON.stringify(
    {
      type: 'drawboard',
      version: 1,
      elements: elements.filter(el => !el.isDeleted),
      createdAt: new Date().toISOString(),
    },
    null,
    2,
  )
}

export function importFromJSON(jsonString: string): IDrawboardElement[] {
  try {
    const data = JSON.parse(jsonString)
    if (data.type !== 'drawboard' || !Array.isArray(data.elements)) {
      throw new Error('Invalid Drawboard JSON format')
    }
    return data.elements
  } catch (error) {
    console.error('Failed to import JSON:', error)
    throw new Error('Invalid JSON format')
  }
}

function calculateBounds(elements: IDrawboardElement[]): {
  minX: number
  minY: number
  maxX: number
  maxY: number
} {
  if (elements.length === 0) {
    return { minX: 0, minY: 0, maxX: 100, maxY: 100 }
  }

  let minX = Infinity
  let minY = Infinity
  let maxX = -Infinity
  let maxY = -Infinity

  elements.forEach(element => {
    if (element.isDeleted) return

    const elementMinX = element.x
    const elementMinY = element.y
    const elementMaxX = element.x + Math.abs(element.width)
    const elementMaxY = element.y + Math.abs(element.height)

    minX = Math.min(minX, elementMinX)
    minY = Math.min(minY, elementMinY)
    maxX = Math.max(maxX, elementMaxX)
    maxY = Math.max(maxY, elementMaxY)
  })

  // Add some padding to bounds
  const padding = 10
  return {
    minX: minX - padding,
    minY: minY - padding,
    maxX: maxX + padding,
    maxY: maxY + padding,
  }
}
