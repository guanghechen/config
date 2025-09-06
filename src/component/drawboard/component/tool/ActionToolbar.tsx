import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import {
  ClearIcon,
  ExportIcon,
  GridIcon,
  RedoIcon,
  UndoIcon,
  ZoomInIcon,
  ZoomOutIcon,
} from '../icons/MaterialIcons'
import { Island, ToolButton, ToolSeparator } from '../ui'

export const ActionToolbar: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)
  const viewData = useStateValue(viewmodel.viewData$)

  const handleZoomIn = (): void => {
    const newZoom = Math.min(viewData.zoom * 1.2, 5)
    viewmodel.setZoom(newZoom)
  }

  const handleZoomOut = (): void => {
    const newZoom = Math.max(viewData.zoom / 1.2, 0.1)
    viewmodel.setZoom(newZoom)
  }

  const handleExport = async (): Promise<void> => {
    try {
      const elements = viewmodel.elements$.getSnapshot()
      const { exportToPNG } = await import('../../util/export')

      const blob = await exportToPNG(elements, { backgroundColor: appState.viewBackgroundColor })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'drawboard-drawing.png'
      a.click()
      URL.revokeObjectURL(url)
    } catch (error) {
      console.error('Export failed:', error)
    }
  }

  const handleClear = (): void => {
    if (
      window.confirm('Are you sure you want to clear the canvas? This action cannot be undone.')
    ) {
      viewmodel.clearCanvas()
    }
  }

  return (
    <Island className="flex flex-col gap-0.5" padding="sm">
      {/* History Controls */}
      <ToolButton
        icon={UndoIcon}
        label="Undo"
        shortcut="Ctrl+Z"
        onClick={() => viewmodel.undo()}
        disabled={!viewmodel.canUndo()}
        variant="secondary"
        size="small"
        aria-label="Undo last action"
      />

      <ToolButton
        icon={RedoIcon}
        label="Redo"
        shortcut="Ctrl+Y"
        onClick={() => viewmodel.redo()}
        disabled={!viewmodel.canRedo()}
        variant="secondary"
        size="small"
        aria-label="Redo last undone action"
      />

      <ToolSeparator />

      {/* View Controls */}
      <ToolButton
        icon={GridIcon}
        label="Toggle Grid"
        shortcut="Ctrl+'"
        isActive={viewData.showGrid}
        onClick={() => viewmodel.toggleGrid()}
        variant="secondary"
        size="small"
        aria-label={viewData.showGrid ? 'Hide grid' : 'Show grid'}
      />

      <ToolSeparator />

      {/* Zoom Controls */}
      <ToolButton
        icon={ZoomInIcon}
        label="Zoom In"
        shortcut="Ctrl++"
        onClick={handleZoomIn}
        disabled={viewData.zoom >= 5}
        size="small"
        aria-label="Zoom in"
      />

      <ToolButton
        icon={ZoomOutIcon}
        label="Zoom Out"
        shortcut="Ctrl+-"
        onClick={handleZoomOut}
        disabled={viewData.zoom <= 0.1}
        size="small"
        aria-label="Zoom out"
      />

      <ToolSeparator />

      {/* Canvas Actions */}
      <ToolButton
        icon={ClearIcon}
        label="Clear Canvas"
        shortcut="Ctrl+Shift+X"
        onClick={handleClear}
        variant="danger"
        size="small"
        aria-label="Clear entire canvas"
      />

      <ToolSeparator />

      {/* Export */}
      <ToolButton
        icon={ExportIcon}
        label="Export"
        shortcut="Ctrl+E"
        onClick={() => {
          handleExport().catch(console.error)
        }}
        size="small"
        aria-label="Export drawing as PNG"
      />
    </Island>
  )
}
