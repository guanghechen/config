import type { Node } from '@xyflow/react'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import type { IReactFlowNodeData } from '../../util/graph/adaptor'

interface IProps {
  readonly node: Node | null
  readonly theme?: 'light' | 'dark'
  readonly onClose: () => void
}

export const NodeDetailsPanel: React.FC<IProps> = props => {
  const { node, onClose } = props
  const [width, setWidth] = React.useState(480)
  const [isDragging, setIsDragging] = React.useState(false)
  const startX = React.useRef(0)
  const startWidth = React.useRef(0)

  const handleMouseDown = React.useCallback(
    (e: React.MouseEvent) => {
      setIsDragging(true)
      startX.current = e.clientX
      startWidth.current = width
      e.preventDefault()
    },
    [width],
  )

  const handleMouseMove = React.useCallback(
    (e: MouseEvent) => {
      if (!isDragging) return
      const deltaX = startX.current - e.clientX
      const newWidth = Math.max(320, Math.min(800, startWidth.current + deltaX))
      setWidth(newWidth)
    },
    [isDragging],
  )

  const handleMouseUp = React.useCallback(() => {
    setIsDragging(false)
  }, [])

  React.useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove)
      document.addEventListener('mouseup', handleMouseUp)
      return () => {
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
      }
    }
  }, [isDragging, handleMouseMove, handleMouseUp])

  if (!node) return null

  return (
    <div
      className="bg-white dark:bg-gray-900 border-l border-gray-200 dark:border-gray-600 flex flex-col relative"
      style={{ width: `${width}px` }}
    >
      <div
        className={cn(
          'absolute left-0 top-0 bottom-0 w-1 cursor-col-resize bg-transparent hover:bg-blue-500 transition-colors z-10',
          {
            'bg-blue-500': isDragging,
          },
        )}
        onMouseDown={handleMouseDown}
      />
      <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-600">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Node Details</h3>
        <button
          onClick={onClose}
          className="text-gray-400 hover:text-gray-600 dark:text-gray-400 dark:hover:text-gray-200 transition-colors"
          aria-label="Close details panel"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
            UUID
          </label>
          <div className="font-mono text-sm bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 p-2 rounded border dark:border-gray-700">
            {(node.data as IReactFlowNodeData).uuid}
          </div>
        </div>

        {(node.data as IReactFlowNodeData).parents.length > 0 && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
              Parent Nodes
            </label>
            <div className="space-y-1">
              {(node.data as IReactFlowNodeData).parents.map(parentId => {
                const isVirtualEdge = parentId.startsWith('@v:')
                const actualParentId = isVirtualEdge ? parentId.slice(3) : parentId

                return (
                  <div
                    key={parentId}
                    className={`font-mono text-sm p-2 rounded border flex items-center gap-2 ${
                      isVirtualEdge
                        ? 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 border-dashed'
                        : 'bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 border-solid dark:border-gray-700'
                    }`}
                  >
                    {isVirtualEdge && <span className="text-xs opacity-60">⋯</span>}
                    {actualParentId}
                    {isVirtualEdge && <span className="text-xs opacity-60 ml-auto">(virtual)</span>}
                  </div>
                )
              })}
            </div>
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
            Position
          </label>
          <div className="font-mono text-sm bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 p-2 rounded border dark:border-gray-700">
            x: {node.position.x.toFixed(2)}, y: {node.position.y.toFixed(2)}
          </div>
        </div>

        {!!(node.data as IReactFlowNodeData).data && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-2">
              Data Content
            </label>
            <div className="bg-gray-50 dark:bg-gray-800 p-3 rounded border dark:border-gray-700 overflow-x-auto">
              <Json json={(node.data as IReactFlowNodeData).data} initialCollapsed="expanded" />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

NodeDetailsPanel.displayName = 'ReactFlowNodeDetailsPanel'
