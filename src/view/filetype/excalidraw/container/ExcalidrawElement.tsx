import type { AppState } from '@excalidraw/excalidraw/types'
import type { Root } from '@yozora/ast'
import React from 'react'
import { MarkdownContentProvider, ReactMarkdown, parseMarkdown } from '@/component/markdown'

interface ITextElement {
  readonly id: string
  readonly text: string
  readonly x: number
  readonly y: number
}

interface IProps {
  readonly element: ITextElement
  readonly appState?: AppState
}

export const ExcalidrawElementRenderer: React.FC<IProps> = ({ element, appState }) => {
  const ast = React.useMemo((): Root | null => {
    try {
      const text = element.text.slice(3) // Remove 'md:' prefix
      return parseMarkdown(text)
    } catch {
      return null
    }
  }, [element.text])

  if (!ast) return null

  const scrollX = appState?.scrollX ?? 0
  const scrollY = appState?.scrollY ?? 0
  const zoom = appState?.zoom ?? 1

  return (
    <div
      className="absolute bg-white/90 dark:bg-gray-800/90 rounded p-2 border border-gray-200 dark:border-gray-600 shadow-sm pointer-events-auto"
      style={{
        transform: `translate(${element.x + scrollX}px, ${element.y + scrollY}px) scale(${zoom})`,
        transformOrigin: 'top left',
        maxWidth: '300px',
      }}
    >
      <MarkdownContentProvider ast={ast}>
        <ReactMarkdown ast={ast} dontShowFirstHeading={false} className="text-sm" />
      </MarkdownContentProvider>
    </div>
  )
}

ExcalidrawElementRenderer.displayName = 'ExcalidrawElementRenderer'
