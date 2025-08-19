import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import type { ITextTransformedNode } from '@/shared/types'
import type { IChainPath } from '../context'
import { extractValueFromPath, getPathColorClasses } from '../utils'

interface IProps {
  readonly index: number
  readonly node: ITextTransformedNode
  readonly chainPaths: IChainPath[]
  readonly expandTick: number
  readonly isActive?: boolean
}

export const ListItemCard: React.FC<IProps> = props => {
  const { index, node, chainPaths, expandTick, isActive = false } = props
  const { uuid, parents, data } = node
  const [expanded, setExpanded] = React.useState(false)

  // Compute extracted values for visible chain paths from this node
  const visibleChainPaths = React.useMemo(() => chainPaths.filter(cp => cp.visible), [chainPaths])
  const allPathStrings = React.useMemo(() => chainPaths.map(cp => cp.path), [chainPaths])

  const extractedValues = React.useMemo(() => {
    if (!visibleChainPaths.length || !data) return []

    return visibleChainPaths.map(chainPath => ({
      path: chainPath.path,
      value: extractValueFromPath(data, chainPath.path),
    }))
  }, [visibleChainPaths, data])

  React.useEffect(() => {
    const flag: boolean = expandTick % 2 === 0
    setExpanded(flag)
  }, [expandTick])

  const handleToggleExpand = React.useCallback(() => {
    setExpanded(prev => !prev)
  }, [])

  return (
    <div
      className={cn('rounded-lg border bg-white shadow-sm transition-all dark:bg-gray-800', {
        'border-indigo-300 bg-gradient-to-br from-indigo-50 to-purple-50 shadow-md ring-1 ring-indigo-200/50 dark:border-indigo-500/60 dark:bg-gradient-to-br dark:from-indigo-950/60 dark:to-purple-950/40 dark:ring-1 dark:ring-indigo-400/20':
          isActive,
        'border-gray-200 dark:border-gray-700': !isActive,
      })}
      data-content-index={index}
    >
      <div
        className={cn('flex cursor-pointer items-center justify-between p-3 transition-colors', {
          'hover:bg-indigo-100/70 dark:hover:bg-indigo-900/30': isActive,
          'hover:bg-gray-50 dark:hover:bg-gray-700': !isActive,
        })}
        onClick={handleToggleExpand}
      >
        <div className="flex select-none items-center gap-2">
          <span className="rounded bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-800 dark:bg-purple-900 dark:text-purple-300">
            #{index}
          </span>
          {extractedValues.map((item, idx) => (
            <span
              key={idx}
              className={cn(
                'rounded px-2 py-0.5 text-xs font-medium',
                item.value === 'undefined'
                  ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300'
                  : getPathColorClasses(item.path, allPathStrings),
              )}
              title={`${item.path}: ${item.value}`}
            >
              {item.value}
            </span>
          ))}
          {parents.length > 0 && (
            <span className="rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-700 dark:text-gray-300">
              {parents.length} parent{parents.length > 1 ? 's' : ''}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <span className="select-none text-xs text-gray-500 dark:text-gray-400">
            {typeof data === 'string' ? 'Text' : 'JSON'}
          </span>
          <svg
            className={cn('h-4 w-4 transition-transform text-gray-400', {
              'rotate-180': expanded,
            })}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>
      {expanded && (
        <div
          className={cn('border-t p-3', {
            'border-indigo-200/60 bg-gradient-to-br from-indigo-50/50 to-purple-50/30 dark:border-indigo-500/30 dark:bg-gradient-to-br dark:from-indigo-950/30 dark:to-purple-950/20':
              isActive,
            'border-gray-200 dark:border-gray-700': !isActive,
          })}
        >
          <div
            className={cn('text-sm mb-2', {
              'text-indigo-700 dark:text-indigo-300': isActive,
              'text-gray-600 dark:text-gray-400': !isActive,
            })}
          >
            <span className="font-mono">UUID: {uuid}</span>
            {parents.length > 0 && (
              <span className="ml-4 font-mono">
                Parent{parents.length > 1 ? 's' : ''}: {parents.join(', ')}
              </span>
            )}
          </div>
          <div
            className={cn('font-mono text-sm', {
              'text-indigo-800 dark:text-indigo-200': isActive,
              'text-gray-800 dark:text-gray-200': !isActive,
            })}
          >
            {typeof data === 'string' ? (
              <pre className="whitespace-pre-wrap break-words">{data}</pre>
            ) : (
              <Json json={data} initialCollapsed="expanded" />
            )}
          </div>
        </div>
      )}
    </div>
  )
}

ListItemCard.displayName = 'TextViewListItemCard'
