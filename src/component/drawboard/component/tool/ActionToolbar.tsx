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
  const { ui, grid, layers, history } = useDrawboardContext()
  const backgroundColor = useStateValue(ui.backgroundColor$)
  const interactionState = useStateValue(ui.interactionState$)
  const gridVisible = useStateValue(grid.visible$)

  const handleZoomIn = (): void => {
    const newZoom = Math.min(interactionState.zoom.value * 1.2, 5)
    ui.setZoom(newZoom)
  }

  const handleZoomOut = (): void => {
    const newZoom = Math.max(interactionState.zoom.value / 1.2, 0.1)
    ui.setZoom(newZoom)
  }

  const handleExport = async (): Promise<void> => {
    try {
      const allElements = layers.allElements$.getSnapshot()
      const { exportToPNG } = await import('../../util/export')

      const blob = await exportToPNG(allElements, { backgroundColor })
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
      layers.setActiveLayerElements([])
      const layerData = layers.dump()
      history.updateLayerData(layerData)
      history.saveToHistory()
    }
  }

  return (
    <Island className="flex flex-col gap-0.5" padding="sm">
      {/* History Controls */}
      <ToolButton
        icon={UndoIcon}
        label="Undo"
        shortcut="Ctrl+Z"
        onClick={() => history.undo()}
        disabled={!history.canUndo()}
        variant="secondary"
        size="small"
        aria-label="Undo last action"
      />

      <ToolButton
        icon={RedoIcon}
        label="Redo"
        shortcut="Ctrl+Y"
        onClick={() => history.redo()}
        disabled={!history.canRedo()}
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
        isActive={gridVisible}
        onClick={() => grid.toggleGridVisibility()}
        variant="secondary"
        size="small"
        aria-label={gridVisible ? 'Hide grid' : 'Show grid'}
      />

      <ToolSeparator />

      {/* Zoom Controls */}
      <ToolButton
        icon={ZoomInIcon}
        label="Zoom In"
        shortcut="Ctrl++"
        onClick={handleZoomIn}
        disabled={interactionState.zoom.value >= 5}
        size="small"
        aria-label="Zoom in"
      />

      <ToolButton
        icon={ZoomOutIcon}
        label="Zoom Out"
        shortcut="Ctrl+-"
        onClick={handleZoomOut}
        disabled={interactionState.zoom.value <= 0.1}
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
