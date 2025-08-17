import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/shared/constant'
import { EventCard } from '../container/EventCard'
import { MultiPathInput } from '../container/MultiPathInput'
import { ModeEnum, useEventStreamViewViewModel } from '../context'
import { Navigation } from '../pane/nav'
import type { IEventStreamEvent } from '../utils'

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📡</div>
      <div>{message}</div>
    </div>
  </div>
)

export const Main: React.FC = () => {
  const viewmodel = useEventStreamViewViewModel()
  const events = useStateValue(viewmodel.events$)
  const mode = useStateValue(viewmodel.mode$)
  const activeEventIndex = useStateValue(viewmodel.activeEventIndex$)
  const chainPaths = useStateValue(viewmodel.chainPaths$)
  const displayMode = useStateValue(viewmodel.displayMode$)

  const showView = (mode & ModeEnum.VIEW) !== 0
  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)

  const scrollToEvent = React.useCallback(
    (index: number) => {
      const element = document.querySelector(`[data-event-index="${index}"]`)
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'center' })
        viewmodel.activeEventIndex$.setState(() => index)
      }
    },
    [viewmodel],
  )

  if (!events || events.length === 0) {
    return <EmptyState message="No valid events found in stream" />
  }

  return (
    <div className="size-full flex justify-center">
      {showView && (
        <React.Fragment>
          <div
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
                  onChange={paths => viewmodel.chainPaths$.setState(() => paths)}
                  displayMode={displayMode}
                  onDisplayModeChange={mode => viewmodel.displayMode$.setState(() => mode)}
                  placeholder="Add JSON paths (e.g., .data.type, .message)"
                />
              </div>
              <div className="p-6 pt-4">
                <div className="space-y-4">
                  {events.map((event: IEventStreamEvent, index: number) => (
                    <div key={`${event.id || index}`} data-event-index={index}>
                      <EventCard event={event} index={index} chainPaths={chainPaths} />
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
            events={events}
            singleColumn={columns === 1}
            onEventClick={scrollToEvent}
            activeEventIndex={activeEventIndex}
          />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'EventStreamViewMain'
