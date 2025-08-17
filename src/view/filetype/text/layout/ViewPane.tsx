import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import type { ITextTransformedNode } from '@/shared/transform/types'
import { ViewModeDropdown } from '../container/ViewModeDropdown'
import { ViewModeEnum } from '../context'

interface IProps {
  readonly content: string
  readonly viewMode: ViewModeEnum
  readonly transformedNodes: ITextTransformedNode[] | null
  readonly columns: number
}

export const ViewPane: React.FC<IProps> = props => {
  const { content, viewMode, transformedNodes, columns } = props

  return (
    <div>
      <div className="relative w-full">
        <ViewModeDropdown />
      </div>
      <div
        className={cn('h-full w-[72rem] max-w-[100rem] flex-auto', PRESET_CLASSES.scrollbar, {
          'p-2 overflow-auto': columns > 1,
          'p-8': columns === 1,
        })}
      >
        {viewMode === ViewModeEnum.LIST && transformedNodes ? (
          <div className="space-y-4">
            <div className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-4">
              Transformed Nodes ({transformedNodes.length})
            </div>
            {transformedNodes.map(node => (
              <div
                key={node.uuid}
                className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-gray-50 dark:bg-gray-800/50"
              >
                <div className="text-sm text-gray-600 dark:text-gray-400 mb-2">
                  <span className="font-mono">UUID: {node.uuid}</span>
                  {node.parents.length > 0 && (
                    <span className="ml-4 font-mono">
                      Parent{node.parents.length > 1 ? 's' : ''}: {node.parents.join(', ')}
                    </span>
                  )}
                </div>
                <div className="font-mono text-sm text-gray-800 dark:text-gray-200">
                  {typeof node.data === 'string' ? (
                    <pre className="whitespace-pre-wrap break-words">{node.data}</pre>
                  ) : (
                    <pre className="whitespace-pre-wrap break-words">
                      {JSON.stringify(node.data, null, 2)}
                    </pre>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800 dark:text-gray-200">
            {content}
          </pre>
        )}
      </div>
    </div>
  )
}

ViewPane.displayName = 'TextViewPane'
