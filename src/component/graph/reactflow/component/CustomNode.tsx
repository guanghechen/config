import { Handle, type NodeProps, Position } from '@xyflow/react'
import cn from 'clsx'
import React from 'react'
import type { IReactFlowNodeData } from '../util/adaptor'

interface IProps extends NodeProps<IReactFlowNodeData> {
  readonly theme?: 'light' | 'dark'
}

export const CustomNode: React.FC<IProps> = props => {
  const { data, selected, theme = 'light' } = props

  const displayText = React.useMemo(() => {
    if (typeof data.data === 'string') {
      return data.data.length > 100 ? `${data.data.slice(0, 100)}...` : data.data
    }
    return JSON.stringify(data.data, null, 0).slice(0, 100)
  }, [data.data])

  return (
    <div
      className={cn(
        'px-4 py-3 rounded-lg border-2 min-w-80 min-h-32 max-w-96 transition-colors font-mono text-xs',
        'flex flex-col items-start justify-start text-left',
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

      <div className="w-full space-y-2">
        <div className="font-semibold text-xs text-blue-600 dark:text-blue-400 break-all">
          {data.uuid}
        </div>
        <div className="text-xs text-gray-700 dark:text-gray-300 break-words leading-relaxed">
          {displayText}
        </div>
      </div>

      <Handle type="source" position={Position.Bottom} className="w-2 h-2" />
    </div>
  )
}

CustomNode.displayName = 'ReactFlowCustomNode'
