import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { EventCard } from './EventCard'
import { MultiPathInput } from './MultiPathInput'
import { EventStreamNavigation } from './navigation'
import { parseEventStream } from './utils'

enum EventStreamModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
}

interface IProps {
  readonly content: string | undefined
}

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📡</div>
      <div>{message}</div>
    </div>
  </div>
)

export const EventStreamComposer: React.FC<IProps> = ({ content }) => {
  const events = React.useMemo(() => parseEventStream(content || ''), [content])
  const [mode, setMode] = React.useState<number>(EventStreamModeEnum.VIEW)
  const [activeEventIndex, setActiveEventIndex] = React.useState<number | null>(null)
  const [expandedEvents, setExpandedEvents] = React.useState<Set<number>>(new Set())
  const [chainPaths, setChainPaths] = React.useState<string[]>([])
  const contentContainerRef = React.useRef<HTMLDivElement | null>(null)

  const showView = mode === 0 || (mode & EventStreamModeEnum.VIEW) !== 0
  const showNavigation = (mode & EventStreamModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)
  const allExpanded = events.length > 0 && expandedEvents.size === events.length

  const scrollToEvent = React.useCallback((index: number) => {
    const container = contentContainerRef.current
    if (!container) return

    const eventCard = container.querySelector(`[data-event-index="${index}"]`) as HTMLElement
    if (eventCard) {
      eventCard.scrollIntoView({ behavior: 'smooth', block: 'start' })
      setActiveEventIndex(index)
    }
  }, [])

  const toggleEvent = React.useCallback((index: number) => {
    setExpandedEvents(prev => {
      const newSet = new Set(prev)
      if (newSet.has(index)) newSet.delete(index)
      else newSet.add(index)
      return newSet
    })
  }, [])

  const toggleAllEvents = React.useCallback(() => {
    setExpandedEvents(allExpanded ? new Set() : new Set(events.map((_, index) => index)))
  }, [allExpanded, events])

  if (!content) return <EmptyState message="No event stream data to display" />
  if (events.length === 0) return <EmptyState message="No valid events found in stream" />

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
          onClick={() => setMode(m => m ^ EventStreamModeEnum.VIEW)}
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
          onClick={() => setMode(m => m ^ EventStreamModeEnum.NAVIGATION)}
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
          onClick={toggleAllEvents}
          title={allExpanded ? 'Collapse all events' : 'Expand all events'}
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
            <div className="p-6">
              <div className="mb-6">
                <div className="flex items-center gap-4 mb-3">
                  <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                    Event Stream
                  </h1>
                  <div className="flex-1 max-w-md">
                    <MultiPathInput
                      paths={chainPaths}
                      onChange={setChainPaths}
                      placeholder="Add JSON paths (e.g., .data.type, .message)"
                    />
                  </div>
                </div>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  {events.length} event{events.length !== 1 ? 's' : ''} found
                </p>
              </div>

              <div className="space-y-4">
                {events.map((event, index) => (
                  <div key={`${event.id || index}`} data-event-index={index}>
                    <EventCard
                      event={event}
                      index={index}
                      isExpanded={expandedEvents.has(index)}
                      onToggle={() => toggleEvent(index)}
                      chainPaths={chainPaths}
                    />
                  </div>
                ))}
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
  )
}

EventStreamComposer.displayName = 'EventStreamComposer'
