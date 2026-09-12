import React from 'react'
import { parseDocument } from '@/shared/whiteboard/document'
import { imageNodes } from '@/shared/whiteboard/images'
import type { IImportedImage } from '@/shared/whiteboard/images'
import type { IPoint, IStyle } from '@/shared/whiteboard/model'
import { importImage } from './images'
import type { BoardStore } from './store'

export function useImageImport(
  store: BoardStore,
  style: IStyle,
  message: (text: string) => void,
  selectTool: () => void,
  disabled = false,
): (files: ReadonlyArray<File>, center: IPoint) => void {
  const disabledRef = React.useRef(disabled)
  disabledRef.current = disabled
  const pending = React.useRef<AbortController | null>(null)
  React.useEffect(() => () => pending.current?.abort(), [])
  React.useEffect(() => {
    if (disabled) pending.current?.abort()
  }, [disabled])
  return React.useCallback(
    (files, center): void => {
      if (disabled || !files.length) return
      if (files.length > 20) {
        message('Choose at most 20 images at a time')
        return
      }
      pending.current?.abort()
      const controller = new AbortController()
      pending.current = controller
      const previous = store.getDocument()
      const unsubscribe = store.subscribe(() => {
        if (store.getDocument() !== previous) controller.abort()
      })
      message('')
      void (async () => {
        try {
          const images: IImportedImage[] = []
          for (const file of files) images.push(await importImage(file, controller.signal))
          controller.signal.throwIfAborted()
          if (disabledRef.current) return
          // A pointer preview can precede a commit; never append into its unfinished transaction.
          if (store.getSnapshot().document !== previous)
            throw new Error('Finish the current gesture, then import the images again')
          const nodes = imageNodes(images, center, style)
          const document = parseDocument(
            JSON.stringify({ ...previous, elements: [...previous.elements, ...nodes] }),
          )
          unsubscribe()
          store.commit(document)
          store.select(new Set(nodes.map(node => node.id)))
          selectTool()
          if (images.some(image => image.optimized))
            message('Large images were optimized for embedding; original files are unchanged')
        } catch (error) {
          if (pending.current !== controller || controller.signal.aborted) return
          message(error instanceof Error ? error.message : String(error))
        } finally {
          unsubscribe()
          if (pending.current === controller) pending.current = null
        }
      })()
    },
    [store, style, message, selectTool, disabled],
  )
}
