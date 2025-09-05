import React, { useRef } from 'react'
import { useDrawboardContext } from '../context'
import { DrawboardProvider } from '../context/Provider'
import type { ToolMode } from '../context/types'
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts'
import { usePointerEvents } from '../hooks/usePointerEvents'
import type { DrawboardElement } from '../types/elements'
import { GridCanvas } from './GridCanvas'
import { InteractiveCanvas } from './InteractiveCanvas'
import { StaticCanvas } from './StaticCanvas'
import { PropertiesPanel } from './tools/PropertiesPanel'
import { ToolPanel } from './tools/ToolPanel'

interface IDrawboardProps {
  className?: string
  onSave?: (elements: DrawboardElement[]) => void
  mode?: ToolMode
}

const DrawboardInner: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const { viewmodel } = useDrawboardContext()

  usePointerEvents(containerRef, viewmodel)
  useKeyboardShortcuts(viewmodel)

  return (
    <div className="relative h-full w-full overflow-hidden bg-gray-50">
      {/* Tool Panel */}
      <div className="absolute left-4 top-4 z-20">
        <ToolPanel />
      </div>

      {/* Properties Panel */}
      <div className="absolute right-4 top-4 z-20">
        <PropertiesPanel />
      </div>

      {/* Canvas Container */}
      <div ref={containerRef} className="relative h-full w-full">
        {/* Grid Layer */}
        <GridCanvas />

        {/* Static Canvas - Drawing Elements */}
        <StaticCanvas />

        {/* Interactive Canvas - UI Overlays */}
        <InteractiveCanvas />
      </div>

      {/* Help text */}
      <div className="absolute bottom-4 left-4 text-xs text-gray-500">
        V: Select | L: Line | R: Rectangle | O: Circle | A: Arrow | H: Pan | G: Grid | Space: Pan
        (hold)
      </div>
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
