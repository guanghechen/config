import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/shared/constant/classes'
import { Card } from './container/Card'
import { MultiPathInput } from './container/MultiPathInput'
import { Navigation } from './container/Navigation'
import { type DisplayMode, type IChainPath, ModeEnum, useJsonlViewViewModel } from './context'

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📄</div>
      <div>{message}</div>
    </div>
  </div>
)

export const Composer: React.FC = () => {
  const viewmodel = useJsonlViewViewModel()

  const mode = useStateValue(viewmodel.mode$)
  const activeRecordIndex = useStateValue(viewmodel.activeRecordIndex$)
  const chainPaths = useStateValue(viewmodel.chainPaths$)
  const displayMode = useStateValue(viewmodel.displayMode$)
  const content = useStateValue(viewmodel.content$)
  const records = useStateValue(viewmodel.jsons$)
  const error = useStateValue(viewmodel.error$)

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
    },
    [viewmodel],
  )

  const showView = (mode & ModeEnum.VIEW) !== 0
  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)

  if (error) return <EmptyState message={`Error: ${error}`} />
  if (!content) return <EmptyState message="No JSONL data to display" />
  if (records.length === 0) return <EmptyState message="No valid records found in JSONL" />

  return (
    <div className="w-full">
      <div
        className={cn('flex w-full items-start justify-center', {
          'h-[calc(100vh-7rem)]': columns > 1,
        })}
      >
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
                    {records.map((record, index: number) => (
                      <div key={index} data-record-index={index}>
                        <Card record={record} chainPaths={chainPaths} />
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
    </div>
  )
}

Composer.displayName = 'JsonlComposer'
