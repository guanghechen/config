/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import type {
  ExcalidrawElement,
  ExcalidrawEmbeddableElement,
} from '@excalidraw/excalidraw/element/types'
import type { AppState, ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types'
import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { usePostFile } from '@/hook/api/file/save'
import { createCrossPlatformKeybinding, useKeyBindings } from '@/keybindings'
import { ElementRenderer } from '../container/ExcalidrawElement'
import type { IExcalidrawData } from '../context'
import { useExcalidrawViewViewModel } from '../context'
import '@excalidraw/excalidraw/index.css'

type NonDeleted<TElement extends ExcalidrawElement> = TElement & {
  isDeleted: boolean
}

export const ContentPane: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)

  const viewmodel = useExcalidrawViewViewModel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string = useStateValue(viewmodel.filepath$)
  const content = useStateValue(viewmodel.content$)

  const { save: saveFile } = usePostFile()
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
          return <ElementRenderer element={textElement} appState={appState} />
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

        await saveFile({
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
    <div className="relative box-border size-full">
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
  )
}

ContentPane.displayName = 'ExcalidrawViewContentPane'
