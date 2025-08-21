import { Handle, type NodeProps, Position } from '@xyflow/react'
import cn from 'clsx'
import React from 'react'
import { displayValue, extractValueFromPath, getPathColorClasses } from '@/view/filetype/text/utils'
import type { IReactFlowNodeData } from '../../util/graph/adaptor'

interface IProps extends NodeProps {
  readonly data: IReactFlowNodeData & { theme?: 'light' | 'dark' }
}

export const CustomNode: React.FC<IProps> = props => {
  const { data, selected } = props
  const theme = data.theme || 'light'

  const truncatedTitle = React.useMemo(() => {
    const title = data.title || ''
    return title.length > 12 ? `${title.slice(0, 12)}...` : title
  }, [data.title])

  // Extract values from chainPaths
  const extractedValues = React.useMemo(() => {
    if (!data.chainPaths || !data.chainPaths.length || !data.data) return []

    return data.chainPaths.map(path => ({
      path,
      value: extractValueFromPath(data.data, path),
    }))
  }, [data.chainPaths, data.data])

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
          'bg-gray-600 border-blue-500 text-gray-100': theme === 'dark' && selected,
        },
      )}
    >
      <Handle
        type="target"
        position={Position.Top}
        className={cn('w-2 h-2', {
          'bg-gray-400 border-gray-500': theme === 'light',
          'bg-gray-600 border-gray-400': theme === 'dark',
        })}
      />

      <div className="w-full space-y-2">
        {/* First line: Index, UUID on left, title with rounded border on right */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <span className="rounded bg-gray-200 px-2 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-600 dark:text-gray-200 flex-shrink-0">
              #{data.index}
            </span>
            <div className="font-semibold text-xs text-blue-600 dark:text-blue-400 break-all flex-1 min-w-0">
              {data.uuid}
            </div>
          </div>
          {truncatedTitle && (
            <div
              className={cn('px-2 py-1 rounded-md text-xs font-medium flex-shrink-0', {
                'bg-green-100 text-green-800 border border-green-200': theme === 'light',
                'bg-green-800 text-green-100 border border-green-600': theme === 'dark',
              })}
            >
              {truncatedTitle}
            </div>
          )}
        </div>

        {/* Chain paths extracted values */}
        {extractedValues.length > 0 && (
          <div className="flex flex-wrap gap-1">
            {extractedValues.map((item, idx) => (
              <span
                key={idx}
                className={cn(
                  'rounded px-2 py-0.5 text-xs font-medium',
                  getPathColorClasses(item.path, data.chainPaths || []),
                )}
                title={`${item.path}: ${displayValue(item.value)}`}
              >
                {displayValue(item.value)}
              </span>
            ))}
          </div>
        )}

        {/* Second line and below: Parents, each on a single line */}
        {data.parents && data.parents.length > 0 && (
          <div className="space-y-1">
            {data.parents.map((parent, index) => (
              <div
                key={index}
                className="text-xs break-words leading-relaxed text-gray-700 dark:text-gray-300"
              >
                {parent}
              </div>
            ))}
          </div>
        )}

        {/* Virtual parents */}
        {data.parents_virtual && data.parents_virtual.length > 0 && (
          <div className="space-y-1">
            {data.parents_virtual.map((parent, index) => (
              <div
                key={`virtual-${index}`}
                className="text-xs break-words leading-relaxed text-gray-500 dark:text-gray-400 italic flex items-center gap-1"
              >
                <span className="text-xs opacity-60">⋯</span>
                {parent}
              </div>
            ))}
          </div>
        )}
      </div>

      <Handle
        type="source"
        position={Position.Bottom}
        className={cn('w-2 h-2', {
          'bg-gray-400 border-gray-500': theme === 'light',
          'bg-gray-600 border-gray-400': theme === 'dark',
        })}
      />
    </div>
  )
}

CustomNode.displayName = 'ReactFlowCustomNode'
