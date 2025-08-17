import React from 'react'
import type { IGraphNode } from '../types'

interface INodeTooltipProps {
  node: IGraphNode | null
  position: { x: number; y: number }
  visible: boolean
}

export const NodeTooltip: React.FC<INodeTooltipProps> = ({ node, position, visible }) => {
  if (!visible || !node) return null

  return (
    <div
      className="absolute z-50 bg-gray-900 text-white text-sm rounded-lg px-3 py-2 shadow-lg pointer-events-none"
      style={{
        left: position.x + 10,
        top: position.y - 10,
        transform: 'translateY(-100%)',
      }}
    >
      <div className="font-medium">{node.id}</div>
      {node.parents.length > 0 && (
        <div className="text-gray-300 text-xs mt-1">Parents: {node.parents.join(', ')}</div>
      )}
      {!!node.data && <div className="text-gray-300 text-xs mt-1">Has data content</div>}
    </div>
  )
}
