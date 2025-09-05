import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../context'

export const InteractiveCanvas: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)
  const viewData = useStateValue(viewmodel.viewData$)

  // This component will handle UI overlays like selection boxes,
  // handles for selected elements, etc.
  // For now, it's a placeholder that shows the current tool

  return (
    <div className="absolute inset-0 pointer-events-none">
      {/* Tool indicator */}
      <div className="absolute bottom-4 right-4 rounded bg-black/80 px-2 py-1 text-xs text-white">
        Tool: {getToolName(appState.selectedTool)} | Zoom: {Math.round(viewData.zoom * 100)}%
      </div>

      {/* Selection indicators could go here */}
      {Object.keys(appState.selectedElementIds).length > 0 && (
        <div className="absolute bottom-4 left-4 rounded bg-blue-600 px-2 py-1 text-xs text-white">
          {Object.keys(appState.selectedElementIds).length} selected
        </div>
      )}
    </div>
  )
}

function getToolName(tool: number): string {
  switch (tool) {
    case 1:
      return 'Select'
    case 2:
      return 'Line'
    case 4:
      return 'Rectangle'
    case 8:
      return 'Circle'
    case 16:
      return 'Arrow'
    case 32:
      return 'Pan'
    default:
      return 'Unknown'
  }
}
