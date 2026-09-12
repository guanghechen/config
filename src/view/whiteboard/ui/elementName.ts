import type { IElement } from '@/shared/whiteboard/model'

export function elementName(element: IElement): string {
  const content =
    element.type === 'text'
      ? element.text
      : element.type === 'markdown'
        ? element.source.kind === 'file'
          ? element.source.filepath.split('/').at(-1)!
          : element.source.content
        : element.type === 'shape' || element.type === 'edge'
          ? (element.label ?? '')
          : ''
  const title = content
    .slice(0, 160)
    .split('\n')
    .find(line => line.trim())
    ?.replace(/^#+\s*/, '')
    .trim()
  return (
    title?.slice(0, 60) ||
    (element.type === 'shape'
      ? element.shape
      : element.type === 'stroke'
        ? 'Freehand'
        : element.type === 'edge'
          ? 'Connection'
          : element.type[0].toUpperCase() + element.type.slice(1))
  )
}
