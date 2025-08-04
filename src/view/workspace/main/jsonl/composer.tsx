import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { JsonlCard } from './JsonlCard'
import { MultiPathInput } from './MultiPathInput'
import { JsonlNavigation } from './navigation'
import { usePersistedChainPaths } from './usePersistedChainPaths'
import { parseJsonlContent } from './utils'

enum JsonlModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
}

interface IProps {
  readonly content: string | undefined
}

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📄</div>
      <div>{message}</div>
    </div>
  </div>
)

export const JsonlComposer: React.FC<IProps> = ({ content }) => {
  const records = React.useMemo(() => parseJsonlContent(content || ''), [content])
  const [mode, setMode] = React.useState<number>(JsonlModeEnum.VIEW)
  const [activeRecordIndex, setActiveRecordIndex] = React.useState<number | null>(null)
  const [expandedRecords, setExpandedRecords] = React.useState<Set<number>>(new Set())
  const [chainPaths, setChainPaths, displayMode, setDisplayMode] = usePersistedChainPaths()
  const contentContainerRef = React.useRef<HTMLDivElement | null>(null)

  const showView = mode === 0 || (mode & JsonlModeEnum.VIEW) !== 0
  const showNavigation = (mode & JsonlModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)
  const allExpanded = records.length > 0 && expandedRecords.size === records.length

  const scrollToRecord = React.useCallback((index: number) => {
    const container = contentContainerRef.current
    if (!container) return

    const recordCard = container.querySelector(`[data-record-index="${index}"]`) as HTMLElement
    if (recordCard) {
      recordCard.scrollIntoView({ behavior: 'smooth', block: 'start' })
      setActiveRecordIndex(index)
    }
  }, [])

  const toggleRecord = React.useCallback((index: number) => {
    setExpandedRecords(prev => {
      const newSet = new Set(prev)
      if (newSet.has(index)) newSet.delete(index)
      else newSet.add(index)
      return newSet
    })
  }, [])

  const toggleAllRecords = React.useCallback(() => {
    setExpandedRecords(allExpanded ? new Set() : new Set(records.map((_, index) => index)))
  }, [allExpanded, records])

  if (!content) return <EmptyState message="No JSONL data to display" />
  if (records.length === 0) return <EmptyState message="No valid records found in JSONL" />

  return (
    <div
      className={cn('flex w-full items-start justify-center', {
        'h-[calc(100vh-7rem)]': columns > 1,
      })}
    >
      {/* Mode Toggle */}
      <div className="fixed right-4 top-16 z-50 flex select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95">
        <button
          className={cn(
            'box-border px-3 py-1 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
            showView
              ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => setMode(m => m ^ JsonlModeEnum.VIEW)}
        >
          view
        </button>
        <button
          className={cn(
            'box-border px-3 py-1 transition-all duration-200 focus:outline-none focus:ring-0',
            showNavigation
              ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => setMode(m => m ^ JsonlModeEnum.NAVIGATION)}
        >
          nav
        </button>
        <button
          className={cn(
            'box-border px-3 py-1 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
            allExpanded
              ? 'bg-green-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={toggleAllRecords}
          title={allExpanded ? 'Collapse all records' : 'Expand all records'}
        >
          {allExpanded ? 'collapse' : 'expand'}
        </button>
      </div>
      {showView && (
        <React.Fragment>
          <div
            ref={contentContainerRef}
            className={cn(
              'w-[72rem] max-w-[100rem] flex-auto border-x-4 border-y-20 border-transparent backdrop-blur-md backdrop-saturate-150 bg-white/70 rounded-lg shadow-lg text-slate-800 dark:bg-gray-800/60 dark:text-gray-200',
              {
                'overflow-auto h-full': columns > 1,
                [PRESET_CLASSES.scrollbar]: columns > 1,
              },
            )}
          >
            <div className="relative w-full">
              <div className="p-6 pb-4 border-b border-gray-200 dark:border-gray-700">
                <MultiPathInput
                  chainPaths={chainPaths}
                  onChange={setChainPaths}
                  displayMode={displayMode}
                  onDisplayModeChange={setDisplayMode}
                  placeholder="Add JSON paths (e.g., .data.type, .message)"
                />
              </div>
              <div className="p-6 pt-4">
                <div className="space-y-4">
                  {records.map((record, index) => (
                    <div key={index} data-record-index={index}>
                      <JsonlCard
                        record={record}
                        isExpanded={expandedRecords.has(index)}
                        onToggle={() => toggleRecord(index)}
                        chainPaths={chainPaths}
                      />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
          {columns > 1 && (
            <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
          )}
        </React.Fragment>
      )}
      {showNavigation && (
        <div
          className={cn('flex h-full justify-center', {
            'w-[32rem] flex-col flex-initial': columns > 1,
          })}
        >
          <JsonlNavigation
            records={records}
            singleColumn={columns === 1}
            onRecordClick={scrollToRecord}
            activeRecordIndex={activeRecordIndex}
          />
        </div>
      )}
    </div>
  )
}

JsonlComposer.displayName = 'JsonlComposer'
