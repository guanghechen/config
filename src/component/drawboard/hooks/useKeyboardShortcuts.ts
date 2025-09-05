import { useEffect } from 'react'
import { ToolMode } from '../context/types'
import type { DrawboardViewModel } from '../context/viewmodel'

export function useKeyboardShortcuts(viewmodel: DrawboardViewModel): void {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      // Prevent default for canvas shortcuts
      if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
        return // Don't handle shortcuts when typing in inputs
      }

      switch (event.key.toLowerCase()) {
        case 'v':
          event.preventDefault()
          viewmodel.setTool(ToolMode.SELECT)
          break
        case 'l':
          event.preventDefault()
          viewmodel.setTool(ToolMode.LINE)
          break
        case 'r':
          event.preventDefault()
          viewmodel.setTool(ToolMode.RECTANGLE)
          break
        case 'o':
          event.preventDefault()
          viewmodel.setTool(ToolMode.CIRCLE)
          break
        case 'a':
          event.preventDefault()
          viewmodel.setTool(ToolMode.ARROW)
          break
        case 'h':
          event.preventDefault()
          viewmodel.setTool(ToolMode.PAN)
          break
        case 'g':
          event.preventDefault()
          viewmodel.toggleGrid()
          break
        case 'delete':
        case 'backspace': {
          event.preventDefault()
          const appState = viewmodel.appState$.getSnapshot()
          const selectedIds = Object.keys(appState.selectedElementIds)
          if (selectedIds.length > 0) {
            viewmodel.deleteElements(selectedIds)
          }
          break
        }
        case 'escape':
          event.preventDefault()
          viewmodel.setTool(ToolMode.SELECT)
          break
        case '=':
        case '+':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            const viewData = viewmodel.viewData$.getSnapshot()
            const newZoom = Math.min(viewData.zoom * 1.2, 5)
            viewmodel.setZoom(newZoom)
          }
          break
        case '-':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            const viewData = viewmodel.viewData$.getSnapshot()
            const newZoom = Math.max(viewData.zoom / 1.2, 0.1)
            viewmodel.setZoom(newZoom)
          }
          break
        case '0':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            viewmodel.setZoom(1)
          }
          break
        case ' ':
          event.preventDefault()
          viewmodel.setTool(ToolMode.PAN)
          break
      }
    }

    const handleKeyUp = (event: KeyboardEvent): void => {
      if (event.key === ' ') {
        // Return to previous tool when space is released
        const appState = viewmodel.appState$.getSnapshot()
        if (appState.selectedTool === ToolMode.PAN) {
          viewmodel.setTool(ToolMode.SELECT)
        }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    document.addEventListener('keyup', handleKeyUp)

    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.removeEventListener('keyup', handleKeyUp)
    }
  }, [viewmodel])
}
