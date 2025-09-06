import { useStateValue } from '@guanghechen/react-viewmodel'
import React, { useRef } from 'react'
import { useDrawboardContext } from '../context'
import { DrawboardProvider } from '../context/Provider'
import type { ToolMode } from '../context/types'
import { useKeyboardShortcuts } from '../hook/useKeyboardShortcuts'
import { usePointerEvents } from '../hook/usePointerEvents'
import type { DrawboardElement } from '../types/elements'
import { DrawboardContextMenu } from './context-menu'
import { GridCanvas } from './GridCanvas'
import { RedoIcon, UndoIcon } from './icons/MaterialIcons'
import { InteractiveCanvas } from './InteractiveCanvas'
import { StaticCanvas } from './StaticCanvas'
import { MainToolbar } from './tool'

interface IDrawboardProps {
  className?: string
  onSave?: (elements: DrawboardElement[]) => void
  mode?: ToolMode
}

const DrawboardInner: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const { viewmodel } = useDrawboardContext()
  const viewData = useStateValue(viewmodel.viewData$)

  usePointerEvents(containerRef, viewmodel)
  useKeyboardShortcuts(viewmodel)

  return (
    <div className="relative h-full w-full overflow-hidden bg-gray-50">
      {/* Canvas Container */}
      <div ref={containerRef} className="relative h-full w-full">
        {/* Grid Layer */}
        <GridCanvas />

        {/* Static Canvas - Drawing Elements */}
        <StaticCanvas />

        {/* Interactive Canvas - UI Overlays */}
        <InteractiveCanvas />

        {/* Main Toolbar */}
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-20">
          <MainToolbar />
        </div>
      </div>

      {/* Footer Bar */}
      <div className="absolute bottom-4 left-0 right-0 z-20 px-4">
        <div className="flex justify-between items-center">
          {/* Left side - Zoom and Undo/Redo controls */}
          <div className="flex items-center gap-2">
            <div className="bg-white/90 backdrop-blur-sm rounded-lg border border-gray-200/60 shadow-sm px-2 py-1 flex items-center gap-1">
              {/* Zoom controls */}
              <button
                type="button"
                onClick={() => {
                  const currentZoom = viewData.zoom
                  viewmodel.setZoom(Math.max(0.1, currentZoom - 0.1))
                }}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                title="Zoom out"
              >
                <span className="text-sm font-medium">−</span>
              </button>

              <button
                type="button"
                onClick={() => viewmodel.setZoom(1)}
                className="px-2 py-1 hover:bg-gray-100 rounded transition-colors min-w-[60px] text-center"
                title="Reset zoom"
              >
                <span className="text-sm font-medium">{Math.round(viewData.zoom * 100)}%</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  const currentZoom = viewData.zoom
                  viewmodel.setZoom(Math.min(5, currentZoom + 0.1))
                }}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                title="Zoom in"
              >
                <span className="text-sm font-medium">+</span>
              </button>
            </div>

            {/* Undo/Redo controls */}
            <div className="bg-white/90 backdrop-blur-sm rounded-lg border border-gray-200/60 shadow-sm px-1 py-1 flex items-center gap-1">
              <button
                type="button"
                onClick={() => viewmodel.undo()}
                disabled={!viewmodel.canUndo()}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                title="Undo"
              >
                <UndoIcon className="w-4 h-4" />
              </button>

              <button
                type="button"
                onClick={() => viewmodel.redo()}
                disabled={!viewmodel.canRedo()}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                title="Redo"
              >
                <RedoIcon className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Right side - can be used for other controls */}
          <div />
        </div>
      </div>

      {/* Context Menu */}
      <DrawboardContextMenu />
    </div>
  )
}

export const Drawboard: React.FC<IDrawboardProps> = ({ className, onSave, mode }) => {
  return (
    <DrawboardProvider onSave={onSave} mode={mode}>
      <div className={className}>
        <DrawboardInner />
      </div>
    </DrawboardProvider>
  )
}
