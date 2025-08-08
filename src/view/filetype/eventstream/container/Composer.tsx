import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { useTopbarVisible } from '@/context/workspace'
import { useEventStreamViewViewModel } from '../context/hook'
import { EventStreamModeEnum } from '../context/Provider'
import { EventCard } from './EventCard'
import { MultiPathInput } from './MultiPathInput'
import { EventStreamNavigation } from './navigation'

const EmptyState: React.FC<{ message: string }> = ({ message }) => (
  <div className="flex h-full items-center justify-center">
    <div className="text-center text-gray-500 dark:text-gray-400">
      <div className="mb-2 text-4xl">📡</div>
      <div>{message}</div>
    </div>
  </div>
)

export const EventStreamContainer: React.FC = () => {
  const topbarVisible = useTopbarVisible()
  const viewmodel = useEventStreamViewViewModel()
  const content = useStateValue(viewmodel.content$)
  const mode = useStateValue(viewmodel.mode$)
  const activeEventIndex = useStateValue(viewmodel.activeEventIndex$)
  const expandedEvents = useStateValue(viewmodel.expandedEvents$)
  const chainPaths = useStateValue(viewmodel.chainPaths$)
  const displayMode = useStateValue(viewmodel.displayMode$)

  // Parse events from content
  const events = React.useMemo(() => {
    if (!content) return []
    try {
      return content
        .split('\n')
        .filter(line => line.trim())
        .map((line, index) => {
          try {
            return { ...JSON.parse(line), id: `event-${index}` }
          } catch {
            return { data: line, id: `event-${index}` }
          }
        })
    } catch {
      return []
    }
  }, [content])

  const showView = (mode & EventStreamModeEnum.VIEW) !== 0
  const showNavigation = (mode & EventStreamModeEnum.NAVIGATION) !== 0
  const columns = (showView ? 1 : 0) + (showNavigation ? 1 : 0)
  const allExpanded = events.length > 0 && expandedEvents.size === events.length

  const toggleEvent = React.useCallback(
    (index: number) => {
      viewmodel.expandedEvents$.setState(prev => {
        const newSet = new Set(prev)
        if (newSet.has(index)) {
          newSet.delete(index)
        } else {
          newSet.add(index)
        }
        return newSet
      })
    },
    [viewmodel],
  )

  const toggleAllEvents = React.useCallback(() => {
    viewmodel.expandedEvents$.setState(prev => {
      if (prev.size === events.length) {
        return new Set()
      } else {
        return new Set(events.map((_, index) => index))
      }
    })
  }, [viewmodel, events])

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

  if (!content) return <EmptyState message="No event stream data to display" />
  if (events.length === 0) return <EmptyState message="No valid events found in stream" />

  return (
    <div
      className={cn('flex w-full items-start justify-center', {
        'h-[calc(100vh-7rem)]': columns > 1,
      })}
    >
      {/* Mode Toggle */}
      <div
        className={cn(
          'fixed right-4 z-50 flex select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95',
          topbarVisible ? 'top-16' : 'top-4',
        )}
      >
        <button
          className={cn(
            'box-border px-3 py-1 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
            showView
              ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ EventStreamModeEnum.VIEW)}
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
          onClick={() => viewmodel.mode$.setState(m => m ^ EventStreamModeEnum.NAVIGATION)}
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
                  {events.map((event: any, index: number) => (
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

EventStreamContainer.displayName = 'EventStreamContainer'
