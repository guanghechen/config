import { Handle, type NodeProps, Position } from '@xyflow/react'
import cn from 'clsx'
import React from 'react'
import type { IReactFlowNodeData } from '../util/adaptor'

interface IProps extends NodeProps<IReactFlowNodeData> {
  readonly theme?: 'light' | 'dark'
}

export const CustomNode: React.FC<IProps> = props => {
  const { data, selected, theme = 'light' } = props

  return (
    <div
      className={cn(
        'px-3 py-2 rounded-lg border-2 min-w-24 min-h-16 transition-colors font-mono text-sm',
        'flex items-center justify-center text-center',
        {
          // Light theme styles
          'bg-gray-50 border-gray-300 text-gray-900': theme === 'light' && !selected,
          'bg-blue-50 border-blue-500 text-blue-900': theme === 'light' && selected,
          // Dark theme styles
          'bg-gray-700 border-gray-500 text-gray-100': theme === 'dark' && !selected,
          'bg-blue-700 border-blue-400 text-blue-100': theme === 'dark' && selected,
        },
      )}
    >
      <Handle type="target" position={Position.Top} className="w-2 h-2" />

      <div className="break-all text-xs">{data.uuid.slice(0, 8)}...</div>

      <Handle type="source" position={Position.Bottom} className="w-2 h-2" />
    </div>
  )
}

CustomNode.displayName = 'ReactFlowCustomNode'
