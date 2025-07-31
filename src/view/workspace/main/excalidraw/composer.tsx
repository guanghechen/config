/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { AppState, ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types'
import type { Root } from '@yozora/ast'
import React from 'react'
import '@excalidraw/excalidraw/index.css'
import { ReactMarkdown, parseMarkdown } from '@/component/markdown'
import { SiteTheme } from '@/context/site'
import { createCrossPlatformKeybinding, useKeyBindings } from '@/keybindings'

interface IExcalidrawTextElement {
  readonly id: string
  readonly type: 'text'
  readonly x: number
  readonly y: number
  readonly text: string
  readonly fontSize: number
  readonly fontFamily: number
  readonly textAlign: string
  readonly verticalAlign: string
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

interface ITextElement {
  readonly id: string
  readonly text: string
  readonly x: number
  readonly y: number
}

interface IRenderedTextElement {
  readonly id: string
  readonly ast: Root
  readonly x: number
  readonly y: number
}

interface IProps {
  readonly content: string | undefined
  readonly onSave: (elements: ReadonlyArray<ExcalidrawElement>, appState: AppState) => Promise<void>
  readonly theme: SiteTheme
}

export const ExcalidrawComposer: React.FC<IProps> = props => {
  const { content, onSave, theme } = props
  const excalidrawRef = React.useRef<ExcalidrawImperativeAPI>(null)

  // Convert SiteTheme to Excalidraw theme format
  const excalidrawTheme = React.useMemo((): 'light' | 'dark' => {
    return theme === SiteTheme.DARKEN ? 'dark' : 'light'
  }, [theme])

  const excalidrawData = React.useMemo((): IExcalidrawData | null => {
    if (!content) return null
    try {
      return JSON.parse(content) as IExcalidrawData
    } catch {
      return null
    }
  }, [content])

  // Extract text elements and render them as markdown
  const textElements = React.useMemo((): ITextElement[] => {
    if (!excalidrawData?.elements) return []

    return excalidrawData.elements
      .filter(
        (element: any): element is IExcalidrawTextElement =>
          element.type === 'text' && 'text' in element && typeof (element as any).text === 'string',
      )
      .map(
        (element): ITextElement => ({
          id: element.id,
          text: (element as any).text,
          x: element.x,
          y: element.y,
        }),
      )
  }, [excalidrawData])

  const renderedTextElements = React.useMemo((): IRenderedTextElement[] => {
    return textElements
      .map((element): IRenderedTextElement | null => {
        try {
          const ast = parseMarkdown(element.text)
          return {
            ast,
            id: element.id,
            x: element.x,
            y: element.y,
          }
        } catch {
          return null
        }
      })
      .filter((element): element is IRenderedTextElement => element !== null)
  }, [textElements])

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
        />
      </div>

      {/* Render text elements as markdown overlays */}
      {renderedTextElements.length > 0 && (
        <div className="fixed inset-0 top-16 pointer-events-none z-10">
          {renderedTextElements.map(element => (
            <div
              key={element.id}
              className="absolute bg-white/90 dark:bg-gray-800/90 rounded p-2 border border-gray-200 dark:border-gray-600 shadow-sm pointer-events-auto"
              style={{
                left: element.x,
                top: element.y,
                maxWidth: '300px',
              }}
            >
              <ReactMarkdown ast={element.ast} dontShowFirstHeading={false} className="text-sm" />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

ExcalidrawComposer.displayName = 'ExcalidrawComposer'
