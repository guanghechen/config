import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'
import {
  ArrowIcon,
  CircleIcon,
  ExportIcon,
  GridIcon,
  LineIcon,
  PanIcon,
  RectangleIcon,
  SelectIcon,
  ZoomInIcon,
  ZoomOutIcon,
} from '../icons/MaterialIcons'

const tools = [
  { mode: ToolMode.SELECT, icon: SelectIcon, label: 'Select' },
  { mode: ToolMode.LINE, icon: LineIcon, label: 'Line' },
  { mode: ToolMode.RECTANGLE, icon: RectangleIcon, label: 'Rectangle' },
  { mode: ToolMode.CIRCLE, icon: CircleIcon, label: 'Circle' },
  { mode: ToolMode.ARROW, icon: ArrowIcon, label: 'Arrow' },
  { mode: ToolMode.PAN, icon: PanIcon, label: 'Pan' },
]

export const ToolPanel: React.FC = () => {
  const { ui, layers, grid } = useDrawboardContext()
  const selectedTool = useStateValue(ui.selectedTool$)
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
      const { exportToPNG, exportToJSON: _exportToJSON } = await import('../../util/export')

      // Export as PNG
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

  return (
    <div className="flex flex-col gap-1 rounded-lg bg-white p-2 shadow-lg">
      {tools.map(({ mode, icon: Icon, label }) => (
        <button
          key={mode}
          onClick={() => ui.setTool(mode)}
          className={cn(
            'group relative flex h-10 w-10 items-center justify-center rounded-lg',
            'transition-colors hover:bg-gray-100',
            {
              'bg-blue-100 text-blue-600': selectedTool === mode,
              'text-gray-700': selectedTool !== mode,
            },
          )}
          title={label}
        >
          <Icon className="h-5 w-5" />
          <span className="absolute left-12 hidden whitespace-nowrap rounded bg-gray-800 px-2 py-1 text-xs text-white group-hover:block">
            {label}
          </span>
        </button>
      ))}

      <div className="my-2 border-t border-gray-200" />

      {/* Grid toggle */}
      <button
        onClick={() => grid.toggleGridVisibility()}
        className={cn(
          'flex h-10 w-10 items-center justify-center rounded-lg transition-colors hover:bg-gray-100',
          {
            'bg-green-100 text-green-600': gridVisible,
            'text-gray-700': !gridVisible,
          },
        )}
        title="Toggle Grid"
      >
        <GridIcon className="h-5 w-5" />
      </button>

      <div className="my-2 border-t border-gray-200" />

      {/* Zoom controls */}
      <button
        onClick={handleZoomIn}
        className="flex h-10 w-10 items-center justify-center rounded-lg text-gray-700 transition-colors hover:bg-gray-100"
        title="Zoom In"
      >
        <ZoomInIcon className="h-5 w-5" />
      </button>

      <button
        onClick={handleZoomOut}
        className="flex h-10 w-10 items-center justify-center rounded-lg text-gray-700 transition-colors hover:bg-gray-100"
        title="Zoom Out"
      >
        <ZoomOutIcon className="h-5 w-5" />
      </button>

      <div className="my-2 border-t border-gray-200" />

      {/* Export */}
      <button
        onClick={() => {
          handleExport().catch(console.error)
        }}
        className="flex h-10 w-10 items-center justify-center rounded-lg text-gray-700 transition-colors hover:bg-gray-100"
        title="Export as PNG"
      >
        <ExportIcon className="h-5 w-5" />
      </button>
    </div>
  )
}
