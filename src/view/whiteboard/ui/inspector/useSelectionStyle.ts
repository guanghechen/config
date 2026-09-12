import React from 'react'
import { DEFAULT_EDGE_APPEARANCE, DEFAULT_STYLE } from '@/shared/whiteboard/model'
import type { IEdgeAppearance, IStyle } from '@/shared/whiteboard/model'
import { hasText } from '@/shared/whiteboard/text'
import type { ITextStyle } from '@/shared/whiteboard/text'
import type { BoardStore } from '../../store'

export function useSelectionStyle(store: BoardStore) {
  const [style, setStyle] = React.useState<IStyle>(DEFAULT_STYLE)
  const [edgeAppearance, setEdgeAppearance] =
    React.useState<IEdgeAppearance>(DEFAULT_EDGE_APPEARANCE)
  const updateStyle = React.useCallback(
    (patch: Partial<IStyle>): void => {
      setStyle(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      if (current.selected.size)
        store.commit({
          ...current.document,
          elements: current.document.elements.map(item =>
            current.selected.has(item.id) ? { ...item, style: { ...item.style, ...patch } } : item,
          ),
        })
    },
    [store],
  )
  const updateTypography = React.useCallback(
    (patch: ITextStyle): void => {
      setStyle(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      store.commit({
        ...current.document,
        elements: current.document.elements.map(element =>
          current.selected.has(element.id) && hasText(element)
            ? { ...element, style: { ...element.style, ...patch } }
            : element,
        ),
      })
    },
    [store],
  )
  const updateAutoSize = React.useCallback(
    (automatic: boolean): void => {
      const current = store.getSnapshot()
      store.commit({
        ...current.document,
        elements: current.document.elements.map(element =>
          current.selected.has(element.id) && (element.type === 'text' || element.type === 'shape')
            ? { ...element, autoSize: automatic }
            : element,
        ),
      })
    },
    [store],
  )
  const updateEdgeAppearance = React.useCallback(
    (patch: IEdgeAppearance): void => {
      setEdgeAppearance(current => ({ ...current, ...patch }))
      const current = store.getSnapshot()
      if (current.selected.size)
        store.commit({
          ...current.document,
          elements: current.document.elements.map(element => {
            if (element.type !== 'edge' || !current.selected.has(element.id)) return element
            const { controls, ...base } = element
            return {
              ...base,
              ...patch,
              ...((patch.routing === undefined ||
                patch.routing === (element.routing ?? 'straight')) &&
              controls
                ? { controls }
                : {}),
            }
          }),
        })
    },
    [store],
  )
  return {
    style,
    edgeAppearance,
    updateStyle,
    updateTypography,
    updateAutoSize,
    updateEdgeAppearance,
  }
}
