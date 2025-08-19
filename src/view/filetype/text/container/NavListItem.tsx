import cn from 'clsx'
import React from 'react'
import type { ITextTransformedNode } from '@/shared/types'
import type { IChainPath } from '../context'
import { useTextViewViewModel } from '../context'
import { extractValueFromPath, getPathColorClasses } from '../utils'

interface IProps {
  readonly record: ITextTransformedNode
  readonly index: number
  readonly isActive: boolean
  readonly chainPaths: IChainPath[]
}

export const NavListItem: React.FC<IProps> = props => {
  const viewmodel = useTextViewViewModel()
  const { record, index, isActive, chainPaths } = props
  const { data } = record

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

  const handleButtonClick = React.useCallback(() => {
    // Set active record
    viewmodel.activeRecordIndex$.next(index)
  }, [viewmodel, index])

  return (
    <React.Fragment>
      <button
        data-nav-index={index}
        onClick={handleButtonClick}
        className={cn(
          'w-full p-3 mb-2 rounded-lg border text-left transition-all hover:shadow-md',
          isActive
            ? 'bg-blue-50 border-blue-200 dark:bg-blue-900/20 dark:border-blue-700'
            : 'bg-gray-50 border-gray-200 hover:bg-gray-100 dark:bg-gray-700 dark:border-gray-600 dark:hover:bg-gray-600',
        )}
      >
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-2">
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
          </div>
          <div className="flex items-center gap-2">
            {record.parents.length > 0 && (
              <span className="px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800 dark:bg-gray-600 dark:text-gray-300">
                {record.parents.length} parent{record.parents.length > 1 ? 's' : ''}
              </span>
            )}
          </div>
        </div>
        <div className="text-xs text-gray-600 dark:text-gray-400 truncate">
          {typeof record.data === 'string'
            ? record.data.length > 100
              ? `${record.data.slice(0, 100)}...`
              : record.data
            : JSON.stringify(record.data).length > 100
              ? `${JSON.stringify(record.data).slice(0, 100)}...`
              : JSON.stringify(record.data)}
        </div>
      </button>
    </React.Fragment>
  )
}

NavListItem.displayName = 'TextViewNavListItem'
