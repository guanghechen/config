import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../context'
import { LayerCanvas } from './LayerCanvas'

export const StaticCanvas: React.FC = () => {
  const { layers } = useDrawboardContext()
  const layersList = useStateValue(layers.layers$)

  return (
    <React.Fragment>
      {layersList
        .filter(layer => layer.visible)
        .sort((a, b) => a.zIndex - b.zIndex)
        .map(layer => (
          <LayerCanvas
            key={layer.id}
            layerName={layer.id}
            zIndex={layer.zIndex}
            blendMode="normal"
            opacity={layer.opacity}
          />
        ))}
    </React.Fragment>
  )
}
