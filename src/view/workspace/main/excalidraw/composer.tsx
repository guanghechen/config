/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { AppState, ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types'
import React from 'react'
import '@excalidraw/excalidraw/index.css'

interface IProps {
  readonly content: string | undefined
  readonly onSave: (elements: ReadonlyArray<ExcalidrawElement>, appState: AppState) => Promise<void>
}

export const ExcalidrawComposer: React.FC<IProps> = props => {
  const { content, onSave } = props
  const excalidrawRef = React.useRef<ExcalidrawImperativeAPI>(null)

  const excalidrawData = React.useMemo(() => {
    if (!content) return null
    try {
      return JSON.parse(content)
    } catch {
      return null
    }
  }, [content])

  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if ((event.metaKey || event.ctrlKey) && event.key === 's') {
        event.preventDefault()

        if (excalidrawRef.current) {
          const elements = excalidrawRef.current.getSceneElements()
          const appState = excalidrawRef.current.getAppState()
          void onSave(elements, appState)
        }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [onSave])

  if (!excalidrawData) {
    return (
      <div className="p-4 text-red-500">Invalid Excalidraw file: Unable to parse JSON data</div>
    )
  }

  return (
    <div className="fixed inset-0 top-16">
      <$Excalidraw
        excalidrawAPI={api => {
          excalidrawRef.current = api
        }}
        initialData={excalidrawData}
        viewModeEnabled={false}
        zenModeEnabled={false}
        gridModeEnabled={true}
        theme="light"
      />
    </div>
  )
}

ExcalidrawComposer.displayName = 'ExcalidrawComposer'
