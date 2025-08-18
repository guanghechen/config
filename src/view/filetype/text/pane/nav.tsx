import cn from 'clsx'
import React from 'react'
import type { ITextTransformedNode } from '@/shared/types'

interface IProps {
  records: ITextTransformedNode[]
  singleColumn: boolean
  onRecordClick: (index: number) => void
  activeRecordIndex: number | null
}

export const Nav: React.FC<IProps> = ({
  records,
  singleColumn,
  onRecordClick,
  activeRecordIndex,
}) => {
  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    if (activeRecordIndex !== null && containerRef.current) {
      const activeItem = containerRef.current.querySelector(
        `[data-nav-index="${activeRecordIndex}"]`,
      )
      if (activeItem) {
        activeItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }
  }, [activeRecordIndex])

  return (
    <div
      ref={containerRef}
      className={cn(
        'bg-white dark:bg-gray-800 rounded-lg shadow-lg',
        singleColumn ? 'w-full max-w-4xl mx-auto mt-8' : 'w-full h-full overflow-auto',
      )}
    >
      <div className="p-4 border-b border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          Transform Nodes ({records.length})
        </h3>
      </div>
      <div className={cn('p-2', singleColumn ? '' : 'overflow-auto h-[calc(100%-4rem)]')}>
        {records.map((record, index) => (
          <button
            key={record.uuid}
            data-nav-index={index}
            onClick={() => onRecordClick(index)}
            className={cn(
              'w-full p-3 mb-2 rounded-lg border text-left transition-all hover:shadow-md',
              activeRecordIndex === index
                ? 'bg-blue-50 border-blue-200 dark:bg-blue-900/20 dark:border-blue-700'
                : 'bg-gray-50 border-gray-200 hover:bg-gray-100 dark:bg-gray-700 dark:border-gray-600 dark:hover:bg-gray-650',
            )}
          >
            <div className="flex items-center justify-between mb-1">
              <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                Node: {record.uuid}
              </span>
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
                  : JSON.stringify(record.data)
              }
            </div>
          </button>
        ))}
      </div>
    </div>
  )
}

Nav.displayName = 'TextViewNav'