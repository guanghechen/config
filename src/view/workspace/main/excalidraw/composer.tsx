/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import React from 'react'
import '@excalidraw/excalidraw/index.css'

interface IProps {
  readonly content: string | undefined
}

export const ExcalidrawComposer: React.FC<IProps> = props => {
  const { content } = props

  const excalidrawData = React.useMemo(() => {
    if (!content) return null
    try {
      return JSON.parse(content)
    } catch {
      return null
    }
  }, [content])

  if (!excalidrawData) {
    return <div className="p-4 text-red-500">Invalid Excalidraw file: Unable to parse JSON data</div>
  }

  return (
    <div className="fixed inset-0 top-16">
      <$Excalidraw
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
