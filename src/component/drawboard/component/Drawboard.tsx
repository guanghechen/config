import { useStateValue } from '@guanghechen/react-viewmodel'
import React, { useRef } from 'react'
import { useDrawboardContext } from '../context'
import { DrawboardProvider } from '../context/Provider'
import type { ToolMode } from '../context/types'
import { usePointerEvents } from '../hook/usePointerEvents'
import type { IDrawboardElement } from '../types/elements'
import { DrawboardContextMenu } from './context-menu'
import { GridCanvas } from './GridCanvas'
import { InteractiveCanvas } from './InteractiveCanvas'
import { FooterBar } from './layout'
import { DevPerformanceMonitor } from './PerformanceMonitor'
import { StaticCanvas } from './StaticCanvas'
import { MainToolbar } from './tool'

interface IDrawboardProps {
  className?: string
  onSave?: (elements: IDrawboardElement[]) => void
  mode?: ToolMode
}

const DrawboardInner: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const { ui, layers, history } = useDrawboardContext()

  // Use individual state subscriptions for better performance
  const selectedTool = useStateValue(ui.selectedTool$)
  const strokeColor = useStateValue(ui.strokeColor$)
  const fillColor = useStateValue(ui.fillColor$)
  const fillStyle = useStateValue(ui.fillStyle$)
  const strokeWidth = useStateValue(ui.strokeWidth$)
  const strokeStyle = useStateValue(ui.strokeStyle$)
  const roughness = useStateValue(ui.roughness$)
  const opacity = useStateValue(ui.opacity$)

  const appStateForPointerEvents = {
    selectedTool,
    strokeColor,
    fillColor,
    fillStyle,
    strokeWidth,
    strokeStyle,
    roughness,
    opacity,
  }

  usePointerEvents(containerRef, history, layers, ui, appStateForPointerEvents)

  return (
    <div className="relative h-full w-full overflow-hidden bg-gray-50 dark:bg-gray-900">
      <div ref={containerRef} className="relative h-full w-full">
        {/* Grid canvas stays independent for proper grid rendering */}
        <GridCanvas />

        {/* Canvas container - transforms now applied to individual
            canvases for hardware acceleration */}
        <div
          className="drawboard-canvas-container absolute inset-0"
          style={{
            willChange: 'auto', // Let individual canvases handle transforms
          }}
        >
          <StaticCanvas />
        </div>

        {/* Interactive elements that don't move with canvas */}
        <InteractiveCanvas />

        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-30">
          <MainToolbar />
        </div>
      </div>

      <FooterBar />
      <DrawboardContextMenu />
      <DevPerformanceMonitor position="top-right" />
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
