/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { AppState, ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types'
import React from 'react'
import '@excalidraw/excalidraw/index.css'
import { createCrossPlatformKeybinding, useKeyBindings } from '@/keybindings'

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

  const handleSave = React.useCallback(
    (event: KeyboardEvent): void => {
      event.preventDefault()

      if (excalidrawRef.current) {
        const elements = excalidrawRef.current.getSceneElements()
        const appState = excalidrawRef.current.getAppState()
        void onSave(elements, appState)
      }
    },
    [onSave],
  )

  const keybindings = React.useMemo(
    () => [
      // Alt+S keybinding for all platforms
      {
        key: 's',
        altKey: true,
        callback: handleSave,
        priority: 100,
        platform: 'all' as const,
      },
      // Cross-platform Cmd+S (macOS) / Ctrl+S (Windows/Linux) keybindings
      ...createCrossPlatformKeybinding('s', handleSave, {
        useCtrl: true,
        priority: 100,
      }),
    ],
    [handleSave],
  )

  useKeyBindings(keybindings)

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
