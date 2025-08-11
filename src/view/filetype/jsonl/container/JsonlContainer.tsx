import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { type DisplayMode, type IChainPath, ModeEnum, useJsonlViewViewModel } from '../context'
import { Card } from './Card'
import { ModeToggle } from './ModeToggle'
import { MultiPathInput } from './MultiPathInput'
import { Navigation } from './Navigation'

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📄</div>
      <div>{message}</div>
    </div>
  </div>
)

interface IProps {
  readonly topbarVisible: boolean
}

export const JsonlContainer: React.FC<IProps> = props => {
  const { topbarVisible } = props
  const viewmodel = useJsonlViewViewModel()

  const mode = useStateValue(viewmodel.mode$)
  const activeRecordIndex = useStateValue(viewmodel.activeRecordIndex$)
  const expandedRecords = useStateValue(viewmodel.expandedRecords$)
  const chainPaths = useStateValue(viewmodel.chainPaths$)
  const displayMode = useStateValue(viewmodel.displayMode$)

  // TODO: These should come from proper data sources
  const content = null // This needs to be implemented
  const records: any[] = [] // This needs to be implemented
  const contentContainerRef = React.useRef<HTMLDivElement>(null)

  const setChainPaths = React.useCallback(
    (paths: IChainPath[] | ((prev: IChainPath[]) => IChainPath[])) => {
      const newPaths =
        typeof paths === 'function' ? paths(viewmodel.chainPaths$.getSnapshot()) : paths
      viewmodel.chainPaths$.next(newPaths)
    },
    [viewmodel],
  )

  const setDisplayMode = React.useCallback(
    (mode: DisplayMode | ((prev: DisplayMode) => DisplayMode)) => {
      const newMode = typeof mode === 'function' ? mode(viewmodel.displayMode$.getSnapshot()) : mode
      viewmodel.displayMode$.next(newMode)
    },
    [viewmodel],
  )

  const scrollToRecord = React.useCallback(
    (index: number) => {
      viewmodel.activeRecordIndex$.next(index)
      // TODO: Implement actual scrolling logic
    },
    [viewmodel],
  )

  const toggleRecord = React.useCallback(
    (index: number) => {
      const currentExpanded = viewmodel.expandedRecords$.getSnapshot()
      const newExpanded = new Set(currentExpanded)
      if (newExpanded.has(index)) {
        newExpanded.delete(index)
      } else {
        newExpanded.add(index)
      }
      viewmodel.expandedRecords$.next(newExpanded)
    },
    [viewmodel],
  )

  const showView = (mode & ModeEnum.VIEW) !== 0
  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)

  if (!content) return <EmptyState message="No JSONL data to display" />
  if (records.length === 0) return <EmptyState message="No valid records found in JSONL" />

  return (
    <div
      className={cn('flex w-full items-start justify-center', {
        'h-[calc(100vh-7rem)]': columns > 1,
      })}
    >
      <ModeToggle topbarVisible={topbarVisible} />
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
                  {records.map((record: any, index: number) => (
                    <div key={index} data-record-index={index}>
                      <Card
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
          <Navigation
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

JsonlContainer.displayName = 'JsonlContainer'
