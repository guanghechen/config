import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { HistoryControls, ZoomControls } from '../ui'

export const FooterBar: React.FC = () => {
  const { ui, history } = useDrawboardContext()
  const interactionState = useStateValue(ui.interactionState$)

  const handleZoomIn = React.useCallback(() => {
    const currentZoom = interactionState.zoom.value
    ui.setZoom(Math.min(30, currentZoom + 0.1))
  }, [interactionState.zoom.value, ui])

  const handleZoomOut = React.useCallback(() => {
    const currentZoom = interactionState.zoom.value
    ui.setZoom(Math.max(0.1, currentZoom - 0.1))
  }, [interactionState.zoom.value, ui])

  const handleResetZoom = React.useCallback(() => {
    ui.setZoom(1)
  }, [ui])

  const handleUndo = React.useCallback(() => {
    history.undo()
  }, [history])

  const handleRedo = React.useCallback(() => {
    history.redo()
  }, [history])

  return (
    <div className="absolute bottom-4 left-0 right-0 z-30 px-4">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-2">
          <ZoomControls
            zoom={interactionState.zoom.value}
            onZoomIn={handleZoomIn}
            onZoomOut={handleZoomOut}
            onResetZoom={handleResetZoom}
          />

          <HistoryControls
            canUndo={history.canUndo()}
            canRedo={history.canRedo()}
            onUndo={handleUndo}
            onRedo={handleRedo}
          />
        </div>

        <div />
      </div>
    </div>
  )
}
