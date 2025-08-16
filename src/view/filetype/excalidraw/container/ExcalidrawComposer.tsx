/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import type {
  ExcalidrawElement,
  ExcalidrawEmbeddableElement,
} from '@excalidraw/excalidraw/element/types'
import type { AppState, ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types'
import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { SiteTheme } from '@/context/site'
import { usePostFile } from '@/hook/api/file/save'
import { createCrossPlatformKeybinding, useKeyBindings } from '@/keybindings'
import { useExcalidrawViewState } from '../context'
import '@excalidraw/excalidraw/index.css'
import { ExcalidrawElementRenderer } from './ExcalidrawElement'

type NonDeleted<TElement extends ExcalidrawElement> = TElement & {
  isDeleted: boolean
}

interface IExcalidrawData {
  readonly type: string
  readonly version: number
  readonly source: string
  readonly elements: ReadonlyArray<ExcalidrawElement>
  readonly appState: {
    readonly gridSize: number
    readonly viewBackgroundColor: string
  }
}

export const ExcalidrawComposer: React.FC = () => {
  const { content, theme, workspace, filepath } = useExcalidrawViewState()
  const fileSaveHook = usePostFile()
  const excalidrawRef = React.useRef<ExcalidrawImperativeAPI>(null)
  const [elements, setElements] = React.useState<ReadonlyArray<ExcalidrawElement>>([])
  const excalidrawTheme = theme === SiteTheme.DARKEN ? 'dark' : 'light'

  const excalidrawData = React.useMemo((): IExcalidrawData | null => {
    if (!content) return null
    try {
      return JSON.parse(content) as IExcalidrawData
    } catch {
      return null
    }
  }, [content])

  // Validate if text element should be rendered as markdown embeddable
  const validateMarkdownEmbeddable = React.useCallback((link: string): boolean => {
    return link.startsWith('md:')
  }, [])

  const renderEmbeddable = useEventCallback(
    (
      element: NonDeleted<ExcalidrawEmbeddableElement>,
      appState: AppState,
    ): React.ReactElement | null => {
      const textElement = elements.find(el => el.id === element.id) as any
      if (!textElement || textElement.type !== 'text') {
        return <React.Fragment />
      }

      if (textElement.type === 'text') {
        if (textElement.text?.startsWith('md:')) {
          return <ExcalidrawElementRenderer element={textElement} appState={appState} />
        }
      }

      return <React.Fragment />
    },
  )

  const onSave = useEventCallback(
    async (elements: ReadonlyArray<ExcalidrawElement>, appState: AppState): Promise<void> => {
      if (!workspace || !filepath) return

      try {
        const excalidrawData = {
          type: 'excalidraw',
          version: 2,
          source: 'https://excalidraw.com',
          elements: elements.filter(el => !el.isDeleted),
          appState: {
            gridSize: appState.gridSize || 20,
            viewBackgroundColor: appState.viewBackgroundColor || '#ffffff',
          },
        }

        await fileSaveHook.save({
          workspace,
          filepath,
          content: JSON.stringify(excalidrawData, null, 2),
        })
      } catch (error) {
        console.error('Failed to save:', error)
      }
    },
  )

  const handleSave = useEventCallback((event: KeyboardEvent): void => {
    event.preventDefault()

    if (excalidrawRef.current) {
      const elements = excalidrawRef.current.getSceneElements()
      const appState = excalidrawRef.current.getAppState()
      void onSave(elements, appState)
    }
  })

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
    <div className="relative">
      <div className="fixed inset-0 top-16">
        <$Excalidraw
          excalidrawAPI={api => {
            excalidrawRef.current = api
          }}
          initialData={excalidrawData}
          viewModeEnabled={false}
          zenModeEnabled={false}
          gridModeEnabled={true}
          theme={excalidrawTheme}
          onChange={setElements}
          validateEmbeddable={validateMarkdownEmbeddable}
          renderEmbeddable={renderEmbeddable}
        />
      </div>
    </div>
  )
}

ExcalidrawComposer.displayName = 'ExcalidrawComposer'
