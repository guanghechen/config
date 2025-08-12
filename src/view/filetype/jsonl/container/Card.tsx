import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import type { IChainPath, IJsonlRecord } from '../context'
import { useJsonlViewViewModel } from '../context'
import { extractValueFromPath, getPathColorClasses } from '../utils'

interface IProps {
  record: IJsonlRecord
  chainPaths?: IChainPath[]
}

export const Card: React.FC<IProps> = ({ record, chainPaths = [] }) => {
  const viewmodel = useJsonlViewViewModel()
  const expandTick = useStateValue(viewmodel.expandTick$)
  const [expanded, setExpanded] = React.useState(false)

  React.useEffect(() => {
    const flag: boolean = expandTick % 2 === 0
    setExpanded(flag)
  }, [expandTick])

  const handleToggleExpand = React.useCallback(() => {
    setExpanded(prev => !prev)
  }, [])

  const visibleChainPaths = React.useMemo(() => chainPaths.filter(cp => cp.visible), [chainPaths])
  const allPathStrings = React.useMemo(() => chainPaths.map(cp => cp.path), [chainPaths])

  const extractedValues = React.useMemo(() => {
    if (!visibleChainPaths.length || !record.isValid) return []

    return visibleChainPaths.map(chainPath => ({
      path: chainPath.path,
      value: extractValueFromPath(record.parsed, chainPath.path),
    }))
  }, [record.parsed, visibleChainPaths, record.isValid])

  return (
    <div className="mb-3 rounded-lg border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div
        className="flex cursor-pointer items-center justify-between p-3 transition-colors hover:bg-gray-50 dark:hover:bg-gray-750"
        onClick={handleToggleExpand}
      >
        <div className="flex select-none items-center gap-2">
          <span className="rounded bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900 dark:text-blue-300">
            #{record.index}
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
          {!record.isValid && (
            <span className="rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800 dark:bg-red-900 dark:text-red-300">
              Invalid JSON
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <span className="select-none text-xs text-gray-500 dark:text-gray-400">
            {record.content.length} chars | {record.isValid ? 'JSON' : 'Text'}
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
        <div className="border-t border-gray-200 p-3 dark:border-gray-700">
          {record.isValid ? (
            <Json json={record.parsed} initialCollapsed="expanded" />
          ) : (
            <pre className="whitespace-pre-wrap text-sm text-gray-800 dark:text-gray-200">
              {record.content}
            </pre>
          )}
        </div>
      )}
    </div>
  )
}

Card.displayName = 'JsonlCard'
