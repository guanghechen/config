import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { EventCard } from './container/EventCard'
import { ModeToggle } from './container/ModeToggle'
import { MultiPathInput } from './container/MultiPathInput'
import { EventStreamNavigation } from './container/navigation'
import { ModeEnum, useEventStreamViewViewModel } from './context'
import type { IEventStreamEvent } from './utils'

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📡</div>
      <div>{message}</div>
    </div>
  </div>
)

interface IProps {
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const Composer: React.FC<IProps> = props => {
  const { mainScrollableContainer } = props
  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)

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
    <div className="w-full">
      <div
        className={cn('flex w-full items-start justify-center', {
          'h-[calc(100vh-7rem)]': columns > 1,
        })}
      >
        <ModeToggle />
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
            <EventStreamNavigation
              events={events}
              singleColumn={columns === 1}
              onEventClick={scrollToEvent}
              activeEventIndex={activeEventIndex}
            />
          </div>
        )}
      </div>
      <button
        onClick={scrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0',
        )}
        title="Scroll to top"
        aria-label="Scroll to top"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-6 w-6"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
        </svg>
      </button>
    </div>
  )
}

Composer.displayName = 'EventStreamComposer'
