import type { INode, IPoint, IStyle } from '@/shared/whiteboard/model'
import type { ITool } from './tools'

export function createNode(tool: ITool, point: IPoint, style: IStyle): INode {
  const base = { id: crypto.randomUUID(), x: point.x, y: point.y, width: 180, height: 120, style }
  if (tool === 'markdown')
    return {
      ...base,
      type: 'markdown',
      width: 360,
      height: 260,
      source: {
        kind: 'inline',
        content: '# A new idea\n\nDouble-click to edit.\n\n- Connect ideas\n- Explore the details',
      },
    }
  if (tool === 'text')
    return { ...base, type: 'text', width: 260, height: 100, text: 'Your idea', autoSize: true }
  if (tool === 'image')
    return {
      ...base,
      type: 'image',
      width: 320,
      height: 220,
      url: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+a9XkAAAAASUVORK5CYII=',
    }
  if (tool === 'stroke')
    return {
      ...base,
      type: 'stroke',
      points: [
        { x: 0, y: 0 },
        { x: 1, y: 1 },
      ],
    }
  return {
    ...base,
    type: 'shape',
    shape: tool === 'ellipse' || tool === 'diamond' ? tool : 'rectangle',
  }
}
