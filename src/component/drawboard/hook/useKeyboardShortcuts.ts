import React from 'react'
import { ToolMode } from '../context/types'
import type { DrawboardViewModel } from '../context/viewmodel'

interface IShortcutMapping {
  key: string
  numericKey?: string
  modifiers?: string[]
  action: (viewmodel: DrawboardViewModel, event: KeyboardEvent) => void
  preventDefault?: boolean
}

const TOOL_SHORTCUTS: IShortcutMapping[] = [
  {
    key: 'v',
    numericKey: '1',
    action: viewmodel => viewmodel.setTool(ToolMode.SELECT),
    preventDefault: true,
  },
  {
    key: 'q',
    numericKey: '2',
    action: viewmodel => viewmodel.setTool(ToolMode.LASSO),
    preventDefault: true,
  },
  {
    key: 'r',
    numericKey: '3',
    action: viewmodel => viewmodel.setTool(ToolMode.RECTANGLE),
    preventDefault: true,
  },
  {
    key: 'd',
    numericKey: '4',
    action: viewmodel => viewmodel.setTool(ToolMode.DIAMOND),
    preventDefault: true,
  },
  {
    key: 'o',
    numericKey: '5',
    action: viewmodel => viewmodel.setTool(ToolMode.CIRCLE),
    preventDefault: true,
  },
  {
    key: 'a',
    numericKey: '6',
    action: viewmodel => viewmodel.setTool(ToolMode.ARROW),
    preventDefault: true,
  },
  {
    key: 'l',
    numericKey: '7',
    action: viewmodel => viewmodel.setTool(ToolMode.LINE),
    preventDefault: true,
  },
  {
    key: 'p',
    numericKey: '8',
    action: viewmodel => viewmodel.setTool(ToolMode.FREEDRAW),
    preventDefault: true,
  },
  {
    key: 't',
    numericKey: '9',
    action: viewmodel => viewmodel.setTool(ToolMode.TEXT),
    preventDefault: true,
  },
  {
    key: 'i',
    numericKey: '0',
    action: viewmodel => viewmodel.setTool(ToolMode.IMAGE),
    preventDefault: true,
  },
  {
    key: 'e',
    action: viewmodel => viewmodel.setTool(ToolMode.ERASER),
    preventDefault: true,
  },
  {
    key: 'f',
    action: viewmodel => viewmodel.setTool(ToolMode.FRAME),
    preventDefault: true,
  },
  {
    key: 'h',
    action: viewmodel => viewmodel.setTool(ToolMode.PAN),
    preventDefault: true,
  },
]

const UTILITY_SHORTCUTS: IShortcutMapping[] = [
  {
    key: 'z',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        viewmodel.undo()
      }
    },
    preventDefault: true,
  },
  {
    key: 'y',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        viewmodel.redo()
      }
    },
    preventDefault: true,
  },
  {
    key: 'x',
    action: (viewmodel, event) => {
      if ((event.ctrlKey || event.metaKey) && event.shiftKey) {
        if (
          window.confirm('Are you sure you want to clear the canvas? This action cannot be undone.')
        ) {
          viewmodel.clearCanvas()
        }
      }
    },
    preventDefault: true,
  },
  {
    key: 'g',
    action: viewmodel => viewmodel.toggleGrid(),
    preventDefault: true,
  },
  {
    key: 'escape',
    action: viewmodel => {
      viewmodel.clearSelection()
      viewmodel.setTool(ToolMode.SELECT)
    },
    preventDefault: true,
  },
  {
    key: 'delete',
    action: viewmodel => viewmodel.deleteSelectedElements(),
    preventDefault: true,
  },
  {
    key: 'backspace',
    action: viewmodel => viewmodel.deleteSelectedElements(),
    preventDefault: true,
  },
  {
    key: 'x',
    action: viewmodel => viewmodel.switchToLastActiveTool(),
    preventDefault: true,
  },
  {
    key: 'shift+l',
    action: viewmodel => viewmodel.toggleToolLock(),
    preventDefault: true,
  },
]

const ZOOM_SHORTCUTS: IShortcutMapping[] = [
  {
    key: '=',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        const viewData = viewmodel.viewData$.getSnapshot()
        const newZoom = Math.min(viewData.zoom * 1.2, 5)
        viewmodel.setZoom(newZoom)
      }
    },
    preventDefault: true,
  },
  {
    key: '+',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        const viewData = viewmodel.viewData$.getSnapshot()
        const newZoom = Math.min(viewData.zoom * 1.2, 5)
        viewmodel.setZoom(newZoom)
      }
    },
    preventDefault: true,
  },
  {
    key: '-',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        const viewData = viewmodel.viewData$.getSnapshot()
        const newZoom = Math.max(viewData.zoom / 1.2, 0.1)
        viewmodel.setZoom(newZoom)
      }
    },
    preventDefault: true,
  },
  {
    key: '0',
    action: (viewmodel, event) => {
      if (event.ctrlKey || event.metaKey) {
        if (event.shiftKey) {
          viewmodel.zoomToFit()
        } else {
          viewmodel.setZoom(1)
        }
      }
    },
    preventDefault: true,
  },
]

const SELECTION_SHORTCUTS: IShortcutMapping[] = [
  {
    key: 'ctrl+a',
    action: viewmodel => {
      const elements = viewmodel.elements$.getSnapshot()
      viewmodel.selectElements(elements.map(el => el.id))
    },
    preventDefault: true,
  },
  {
    key: 'ctrl+d',
    action: viewmodel => viewmodel.duplicateSelectedElements(),
    preventDefault: true,
  },
]

const createShortcutKey = (key: string): string => {
  const parts = key.split('+')
  return parts[parts.length - 1].toLowerCase()
}

const hasModifiers = (key: string, event: KeyboardEvent): boolean => {
  const parts = key.split('+')
  if (parts.length === 1)
    return !event.ctrlKey && !event.metaKey && !event.shiftKey && !event.altKey

  const expectedCtrl = parts.includes('ctrl')
  const expectedMeta = parts.includes('meta') || parts.includes('cmd')
  const expectedShift = parts.includes('shift')
  const expectedAlt = parts.includes('alt')

  return (
    event.ctrlKey === expectedCtrl &&
    event.metaKey === expectedMeta &&
    event.shiftKey === expectedShift &&
    event.altKey === expectedAlt
  )
}

export function useKeyboardShortcuts(viewmodel: DrawboardViewModel): void {
  React.useEffect(() => {
    const allShortcuts = [
      ...TOOL_SHORTCUTS,
      ...UTILITY_SHORTCUTS,
      ...ZOOM_SHORTCUTS,
      ...SELECTION_SHORTCUTS,
    ]

    const handleKeyDown = (event: KeyboardEvent): void => {
      // Don't handle shortcuts when typing in inputs
      if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
        return
      }

      const pressedKey = event.key.toLowerCase()

      // Check tool shortcuts (including numeric alternatives)
      for (const shortcut of allShortcuts) {
        const shortcutKey = createShortcutKey(shortcut.key)
        const matchesKey = pressedKey === shortcutKey
        const matchesNumeric = shortcut.numericKey && pressedKey === shortcut.numericKey

        if ((matchesKey || matchesNumeric) && hasModifiers(shortcut.key, event)) {
          if (shortcut.preventDefault) {
            event.preventDefault()
          }
          shortcut.action(viewmodel, event)
          return
        }
      }
    }

    const handleKeyUp = (event: KeyboardEvent): void => {
      // Handle space key for temporary pan tool
      if (event.key === ' ') {
        const appState = viewmodel.appState$.getSnapshot()
        if (appState.selectedTool === ToolMode.PAN && appState.lastActiveTool) {
          viewmodel.setTool(appState.lastActiveTool)
        }
      }
    }

    // Special handling for space key (temporary pan)
    const handleSpaceKeyDown = (event: KeyboardEvent): void => {
      if (event.key === ' ' && !event.repeat) {
        event.preventDefault()
        const appState = viewmodel.appState$.getSnapshot()
        if (appState.selectedTool !== ToolMode.PAN) {
          viewmodel.setTool(ToolMode.PAN)
        }
      }
    }

    document.addEventListener('keydown', handleSpaceKeyDown)
    document.addEventListener('keydown', handleKeyDown)
    document.addEventListener('keyup', handleKeyUp)

    return () => {
      document.removeEventListener('keydown', handleSpaceKeyDown)
      document.removeEventListener('keydown', handleKeyDown)
      document.removeEventListener('keyup', handleKeyUp)
    }
  }, [viewmodel])
}

// Export shortcut mappings for use in UI components
export const getToolShortcut = (tool: ToolMode): string | undefined => {
  const shortcut = TOOL_SHORTCUTS.find(s => {
    const action = s.action.toString()
    return action.includes(`ToolMode.${ToolMode[tool]}`)
  })
  return shortcut?.key.toUpperCase()
}

export const getToolNumericShortcut = (tool: ToolMode): string | undefined => {
  const shortcut = TOOL_SHORTCUTS.find(s => {
    const action = s.action.toString()
    return action.includes(`ToolMode.${ToolMode[tool]}`)
  })
  return shortcut?.numericKey
}
