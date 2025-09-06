import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Drawboard } from '@/component/drawboard'
import type { DrawboardElement } from '@/component/drawboard'
import { createCrossPlatformKeybinding, useKeyBindings } from '@/keybindings'
import type { IDrawboardData } from '../context'
import { useDrawboardViewViewModel } from '../context'

export const CanvasPane: React.FC = () => {
  const viewmodel = useDrawboardViewViewModel()
  const content = useStateValue(viewmodel.content$)

  const drawboardData = React.useMemo((): IDrawboardData | null => {
    if (!content) return null
    try {
      return JSON.parse(content) as IDrawboardData
    } catch {
      return null
    }
  }, [content])

  const onSave = useEventCallback(async (elements: DrawboardElement[]): Promise<void> => {
    if (viewmodel.saveFile) {
      const drawboardData: IDrawboardData = {
        nodes: elements,
        edges: [],
        meta: {
          version: 1,
          zoom: 1,
          offsetX: 0,
          offsetY: 0,
          gridSize: 20,
          showGrid: true,
        },
        title: '',
        description: '',
      }
      const content: string = JSON.stringify(drawboardData, null, 2)
      viewmodel.saveFile(content)
    }
  })

  const handleSave = useEventCallback((event: KeyboardEvent): void => {
    event.preventDefault()
    // The drawboard component will call onSave when needed
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

  if (!drawboardData) {
    return <div className="p-4 text-red-500">Invalid Drawboard file: Unable to parse JSON data</div>
  }

  return (
    <div className="relative box-border size-full">
      <Drawboard className="size-full" onSave={onSave} />
    </div>
  )
}

CanvasPane.displayName = 'DrawboardViewCanvasPane'
