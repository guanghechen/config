import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../context'

export const InteractiveCanvas: React.FC = () => {
  const { viewmodel } = useDrawboardContext()
  const appState = useStateValue(viewmodel.appState$)

  // This component will handle UI overlays like selection boxes,
  // handles for selected elements, etc.

  return (
    <div className="absolute inset-0 pointer-events-none z-20">
      {/* Selection indicators could go here */}
      {Object.keys(appState.selectedElementIds).length > 0 && (
        <div className="absolute bottom-4 left-4 rounded bg-blue-600 px-2 py-1 text-xs text-white">
          {Object.keys(appState.selectedElementIds).length} selected
        </div>
      )}
    </div>
  )
}
