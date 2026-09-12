import React from 'react'
import type { IElement, ILabelElement } from '@/shared/whiteboard/model'
import { parseDocument } from '@/shared/whiteboard/document'
import { nodeBounds } from '@/shared/whiteboard/pose'
import type { BoardStore } from '../../store'
import type { IEditSession } from './InlineEditor'
import { useBoardHost } from '../../HostContext'

export function useNodeEditor(
  store: BoardStore,
  readOnly: boolean,
  setMessage: (message: string) => void,
  focusCanvas: () => void,
) {
  const { files } = useBoardHost()
  const editGeneration = React.useRef(0)
  React.useEffect(
    () => () => {
      editGeneration.current++
    },
    [],
  )
  const [editor, setEditor] = React.useState<IEditSession | null>(null)
  const [labelEditor, setLabelEditor] = React.useState<ILabelElement | null>(null)
  const edit = React.useCallback(
    async (node: IElement): Promise<void> => {
      if (readOnly || store.getSnapshot().locked.has(node.id)) return
      if (editor || labelEditor || node.type === 'stroke') return
      const generation = ++editGeneration.current
      if (node.type === 'shape' || node.type === 'edge') {
        store.select(new Set([node.id]))
        setLabelEditor(node)
        return
      }
      let content =
        node.type === 'markdown' && node.source.kind === 'inline'
          ? node.source.content
          : node.type === 'text'
            ? node.text
            : node.type === 'image'
              ? node.url
              : ''
      let sourceFile: string | undefined, sourceRevision: string | undefined
      try {
        if (node.type === 'markdown' && node.source.kind === 'file') {
          setMessage('Loading source for editing…')
          const data = await files!.load(node.source.filepath)
          if (!data || generation !== editGeneration.current) return
          content = data.content
          sourceFile = data.filepath
          sourceRevision = data.revision
          setMessage('')
        }
        if (generation !== editGeneration.current) return
        if (!store.getDocument().elements.some(element => element.id === node.id)) return
        const camera = store.getSnapshot().camera
        const bounds = nodeBounds(node)
        setEditor({
          node,
          content,
          filepath: sourceFile,
          revision: sourceRevision,
          left: bounds.x * camera.zoom + camera.x,
          top: bounds.y * camera.zoom + camera.y,
        })
      } catch (error) {
        if (generation === editGeneration.current)
          setMessage(error instanceof Error ? error.message : String(error))
      }
    },
    [store, editor, labelEditor, readOnly, files, setMessage],
  )
  const saveContent = (content: string): void => {
    if (!editor) return

    const current = store.getSnapshot().document
    if (!editor.filepath) {
      const elements = current.elements.map(item => {
        if (item.id !== editor.node.id) return item
        if (item.type === 'markdown')
          return { ...item, source: { kind: 'inline' as const, content } }
        if (item.type === 'text') return { ...item, text: content }
        if (item.type === 'image') return { ...item, url: content }
        return item
      })
      try {
        store.commit(parseDocument(JSON.stringify({ ...current, elements })))
      } catch (error) {
        setMessage(error instanceof Error ? error.message : String(error))
        return
      }
    }
    setEditor(null)
  }
  const saveLabel = (label: string): void => {
    if (!labelEditor) return

    const current = store.getDocument()
    store.commit({
      ...current,
      elements: current.elements.map(element =>
        element.id === labelEditor.id && (element.type === 'shape' || element.type === 'edge')
          ? { ...element, label }
          : element,
      ),
    })
    setLabelEditor(null)
    focusCanvas()
  }
  return {
    editor,
    labelEditor,
    editGeneration,
    edit,
    saveContent,
    saveLabel,
    closeEditor: () => setEditor(null),
    closeLabel: () => {
      setLabelEditor(null)
      focusCanvas()
    },
  }
}
