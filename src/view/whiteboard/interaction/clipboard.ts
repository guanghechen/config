import React from 'react'
import {
  duplicateElements,
  elementBounds,
  moveElements,
  unionBounds,
  worldPoint,
} from '@/shared/whiteboard/geometry'
import { parseDocument } from '@/shared/whiteboard/document'
import { createDocument } from '@/shared/whiteboard/model'
import type { IElement, IPoint, IStyle } from '@/shared/whiteboard/model'
import { orderedDocument } from '@/shared/whiteboard/stacking'
import type { BoardStore } from '../store'
import { createNode } from './createNode'
import { hasBoardDialog, ownsBoardEvent, typing } from './targets'

export function useBoardClipboard({
  stage,
  store,
  style,
  readOnly,
  isInteracting,
  isDragging,
  finishKeyMove,
  importImages,
  message,
}: {
  stage: React.RefObject<HTMLDivElement | null>
  store: BoardStore
  style: IStyle
  readOnly: boolean
  isInteracting: () => boolean
  isDragging: () => boolean
  finishKeyMove: () => void
  importImages: (files: ReadonlyArray<File>, center: IPoint) => void
  message: (text: string) => void
}) {
  const mounted = React.useRef(true)
  const readOnlyRef = React.useRef(readOnly)
  readOnlyRef.current = readOnly
  React.useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])
  const pasteValue = (value: string, at?: IPoint): void => {
    if (readOnlyRef.current) return
    try {
      const current = store.getSnapshot()
      let elements: ReadonlyArray<IElement>
      if (value.trim().startsWith('{') && value.includes('yoz.whiteboard')) {
        const source = orderedDocument(parseDocument(value))
        elements = duplicateElements(
          source.elements,
          new Set(source.elements.map(element => element.id)),
        )
        if (at) {
          const map = new Map(elements.map(element => [element.id, element]))
          const bounds = unionBounds(elements.map(element => elementBounds(element, map)))
          if (bounds)
            elements = moveElements(elements, new Set(elements.map(element => element.id)), {
              x: at.x - bounds.x - bounds.width / 2,
              y: at.y - bounds.y - bounds.height / 2,
            })
        }
      } else {
        const point =
          at ??
          worldPoint(
            { x: stage.current!.clientWidth / 2, y: stage.current!.clientHeight / 2 },
            current.camera,
          )
        elements = [
          {
            ...createNode('markdown', point, style),
            type: 'markdown',
            source: { kind: 'inline', content: value },
          },
        ]
      }
      store.commit(
        parseDocument(
          JSON.stringify({
            ...current.document,
            elements: [...current.document.elements, ...elements],
          }),
        ),
      )
      store.select(new Set(elements.map(element => element.id)))
    } catch (error) {
      message(error instanceof Error ? error.message : String(error))
    }
  }

  const copyToClipboard = async (cut = false): Promise<void> => {
    finishKeyMove()
    const initial = store.getSnapshot()
    if (!initial.selected.size || (cut && (readOnlyRef.current || !store.canRemoveSelection())))
      return
    try {
      const elements = duplicateElements(initial.document.elements, initial.selected)
      await navigator.clipboard.writeText(JSON.stringify({ ...createDocument(), elements }))
      if (!mounted.current) return
      if (cut) {
        const current = store.getSnapshot()
        if (
          readOnlyRef.current ||
          isInteracting() ||
          hasBoardDialog(stage.current) ||
          current.document !== initial.document ||
          store.getDocument() !== initial.document ||
          current.selected.size !== initial.selected.size ||
          [...initial.selected].some(id => !current.selected.has(id))
        )
          throw new Error(
            'Selection changed while copying. Copied data was kept; cut again to remove it.',
          )
        store.removeSelected()
      }
    } catch (error) {
      if (mounted.current)
        message(
          error instanceof Error
            ? error.message
            : 'Clipboard unavailable; use the keyboard shortcut',
        )
    }
  }

  const pasteFromClipboard = async (point: IPoint): Promise<void> => {
    if (readOnlyRef.current) return
    finishKeyMove()
    const initial = store.getDocument()
    try {
      let text = ''
      const files: File[] = []
      if (navigator.clipboard.read) {
        for (const item of await navigator.clipboard.read()) {
          const type = item.types.find(type => type.startsWith('image/'))
          if (type) files.push(new File([await item.getType(type)], 'clipboard-image', { type }))
          else if (!text && item.types.includes('text/plain'))
            text = await (await item.getType('text/plain')).text()
        }
      } else text = await navigator.clipboard.readText()
      if (!mounted.current) return
      if (
        readOnlyRef.current ||
        store.getDocument() !== initial ||
        store.getSnapshot().document !== initial ||
        isInteracting() ||
        hasBoardDialog(stage.current)
      )
        throw new Error('Whiteboard changed while reading the clipboard. Paste again.')
      if (files.length) importImages(files, point)
      else if (text) pasteValue(text, point)
    } catch (error) {
      if (mounted.current)
        message(
          error instanceof Error
            ? error.message
            : 'Clipboard unavailable; use the keyboard shortcut',
        )
    }
  }

  React.useEffect(() => {
    const copy = (event: ClipboardEvent): boolean => {
      if (
        event.defaultPrevented ||
        !ownsBoardEvent(stage.current, event.target) ||
        typing(event.target) ||
        isDragging() ||
        hasBoardDialog(stage.current) ||
        !event.clipboardData ||
        !store.getSnapshot().selected.size
      )
        return false
      finishKeyMove()
      const { document, selected } = store.getSnapshot()
      const elements = duplicateElements(document.elements, selected)
      event.clipboardData.setData('text/plain', JSON.stringify({ ...createDocument(), elements }))
      event.preventDefault()
      return true
    }
    const cut = (event: ClipboardEvent): void => {
      if (readOnly || !store.canRemoveSelection()) return
      if (copy(event)) store.removeSelected()
    }
    const paste = (event: ClipboardEvent): void => {
      if (readOnly || event.defaultPrevented || !ownsBoardEvent(stage.current, event.target)) return
      if (typing(event.target) || isDragging() || hasBoardDialog(stage.current)) return
      finishKeyMove()
      const files = Array.from(event.clipboardData?.files ?? [])
      if (files.length) {
        event.preventDefault()
        importImages(
          files,
          worldPoint(
            { x: stage.current!.clientWidth / 2, y: stage.current!.clientHeight / 2 },
            store.getSnapshot().camera,
          ),
        )
        return
      }
      const value = event.clipboardData?.getData('text/plain')
      if (!value) return
      event.preventDefault()
      pasteValue(value)
    }

    window.addEventListener('copy', copy)
    window.addEventListener('cut', cut)
    window.addEventListener('paste', paste)
    return () => {
      window.removeEventListener('copy', copy)
      window.removeEventListener('cut', cut)
      window.removeEventListener('paste', paste)
    }
  })
  return { copyToClipboard, pasteFromClipboard }
}
