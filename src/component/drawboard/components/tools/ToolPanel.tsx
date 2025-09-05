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
      const { exportToPNG, exportToJSON: _exportToJSON } = await import('../../utils/export')

      // Export as PNG
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

  return (
    <div className="flex flex-col gap-1 rounded-lg bg-white p-2 shadow-lg">
      {tools.map(({ mode, icon: Icon, label }) => (
        <button
          key={mode}
          onClick={() => viewmodel.setTool(mode)}
          className={cn(
            'group relative flex h-10 w-10 items-center justify-center rounded-lg',
            'transition-colors hover:bg-gray-100',
            {
              'bg-blue-100 text-blue-600': appState.selectedTool === mode,
              'text-gray-700': appState.selectedTool !== mode,
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
        onClick={() => viewmodel.toggleGrid()}
        className={cn(
          'flex h-10 w-10 items-center justify-center rounded-lg transition-colors hover:bg-gray-100',
          {
            'bg-green-100 text-green-600': viewData.showGrid,
            'text-gray-700': !viewData.showGrid,
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
