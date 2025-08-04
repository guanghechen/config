import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import type { IEventStreamEvent } from './utils'
import type { IChainPath } from './usePersistedChainPaths'
import { extractValueFromPath, parseJsonData, getPathColorClasses } from './utils'

interface IProps {
  event: IEventStreamEvent
  index: number
  isExpanded: boolean
  onToggle: () => void
  chainPaths?: IChainPath[]
}

export const EventCard: React.FC<IProps> = ({
  event,
  index,
  isExpanded,
  onToggle,
  chainPaths = [],
}) => {
  const { parsed, isJson } = event.data ? parseJsonData(event.data) : { parsed: '', isJson: false }

  const visibleChainPaths = React.useMemo(() => chainPaths.filter(cp => cp.visible), [chainPaths])
  const allPathStrings = React.useMemo(() => chainPaths.map(cp => cp.path), [chainPaths])

  const extractedValues = React.useMemo(() => {
    if (!visibleChainPaths.length || !isJson) return []

    return visibleChainPaths.map(chainPath => ({
      path: chainPath.path,
      value: extractValueFromPath(parsed, chainPath.path),
    }))
  }, [parsed, visibleChainPaths, isJson])

  return (
    <div className="mb-3 rounded-lg border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div
        className="flex cursor-pointer items-center justify-between p-3 transition-colors hover:bg-gray-50 dark:hover:bg-gray-750"
        onClick={onToggle}
      >
        <div className="flex select-none items-center gap-2">
          <span className="rounded bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900 dark:text-blue-300">
            #{index + 1}
          </span>
          {extractedValues.map((item, idx) => (
            <span
              key={idx}
              className={cn(
                'rounded px-2 py-0.5 text-xs font-medium',
                item.value === 'undefined'
                  ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300'
                  : getPathColorClasses(item.path, allPathStrings)
              )}
              title={`${item.path}: ${item.value}`}
            >
              {item.value}
            </span>
          ))}
          {event.event && (
            <span className="rounded bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-300">
              {event.event}
            </span>
          )}
          {event.id && (
            <span className="rounded bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-800 dark:bg-purple-900 dark:text-purple-300">
              {event.id}
            </span>
          )}
          {event.retry && (
            <span className="rounded bg-orange-100 px-2 py-0.5 text-xs font-medium text-orange-800 dark:bg-orange-900 dark:text-orange-300">
              {event.retry}ms
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {event.data && (
            <span className="select-none text-xs text-gray-500 dark:text-gray-400">
              {event.data.length} chars | {isJson ? 'JSON' : 'Text'}
            </span>
          )}
          <svg
            className={cn('h-4 w-4 transition-transform text-gray-400', {
              'rotate-180': isExpanded,
            })}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>
      {isExpanded && event.data && (
        <div className="border-t border-gray-200 p-3 dark:border-gray-700">
          {isJson ? (
            <Json json={parsed} initialCollapsed="expanded" />
          ) : (
            <pre className="whitespace-pre-wrap text-sm text-gray-800 dark:text-gray-200">
              {String(parsed)}
            </pre>
          )}
        </div>
      )}
    </div>
  )
}
