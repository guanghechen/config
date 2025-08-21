import { type EdgeProps, getSmoothStepPath } from '@xyflow/react'
import React from 'react'

export const VirtualEdge: React.FC<EdgeProps> = ({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  style = {},
  markerEnd,
}) => {
  const [edgePath] = getSmoothStepPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
  })

  return (
    <React.Fragment>
      <path
        id={id}
        style={{
          fill: 'none',
          stroke: style.stroke || '#b1b1b7',
          strokeWidth: style.strokeWidth || 2,
          strokeDasharray: '5,5',
        }}
        className="react-flow__edge-path"
        d={edgePath}
        markerEnd={markerEnd}
      />
    </React.Fragment>
  )
}

VirtualEdge.displayName = 'VirtualEdge'
