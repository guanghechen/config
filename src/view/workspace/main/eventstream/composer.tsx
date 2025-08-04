import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { PRESET_CLASSES } from '@/constant/classes'
import { EventStreamNavigation } from './navigation'

enum EventStreamModeEnum {
  VIEW = 1,
  NAVIGATION = 2,
}

interface IEventStreamEvent {
  id?: string
  event?: string
  data?: string
  retry?: number
}

interface IProps {
  readonly content: string | undefined
}

const parseEventStream = (content: string): IEventStreamEvent[] => {
  if (!content) return []

  const events: IEventStreamEvent[] = []
  const lines = content.split('\n')
  let currentEvent: IEventStreamEvent = {}

  for (const line of lines) {
    const trimmedLine = line.trim()

    // Empty line indicates end of event
    if (trimmedLine === '') {
      if (Object.keys(currentEvent).length > 0) {
        events.push(currentEvent)
        currentEvent = {}
      }
      continue
    }

    // Skip comments
    if (trimmedLine.startsWith(':')) {
      continue
    }

    // Parse field: value
    const colonIndex = trimmedLine.indexOf(':')
    if (colonIndex === -1) continue

    const field = trimmedLine.slice(0, colonIndex).trim()
    const value = trimmedLine.slice(colonIndex + 1).trim()

    switch (field) {
      case 'id':
        currentEvent.id = value
        break
      case 'event':
        currentEvent.event = value
        break
      case 'data':
        currentEvent.data = currentEvent.data ? `${currentEvent.data}\n${value}` : value
        break
      case 'retry':
        currentEvent.retry = parseInt(value, 10)
        break
    }
  }

  // Add final event if exists
  if (Object.keys(currentEvent).length > 0) {
    events.push(currentEvent)
  }

  return events
}

const parseJsonData = (data: string): { parsed: unknown; isJson: boolean } => {
  try {
    const parsed = JSON.parse(data)
    return {
      parsed,
      isJson: true,
    }
  } catch {
    return {
      parsed: data,
      isJson: false,
    }
  }
}

const EventCard: React.FC<{ event: IEventStreamEvent; index: number }> = ({ event, index }) => {
  const { parsed, isJson } = event.data ? parseJsonData(event.data) : { parsed: '', isJson: false }

  return (
    <div className="mb-4 rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-800 dark:bg-blue-900 dark:text-blue-300">
            #{index + 1}
          </span>
          {event.event && (
            <span className="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-300">
              {event.event}
            </span>
          )}
          {event.id && (
            <span className="rounded-full bg-purple-100 px-2 py-1 text-xs font-medium text-purple-800 dark:bg-purple-900 dark:text-purple-300">
              ID: {event.id}
            </span>
          )}
          {event.retry && (
            <span className="rounded-full bg-orange-100 px-2 py-1 text-xs font-medium text-orange-800 dark:bg-orange-900 dark:text-orange-300">
              Retry: {event.retry}ms
            </span>
          )}
        </div>
      </div>

      {event.data && (
        <div className="mt-3">
          <div className="mb-2 text-sm font-medium text-gray-700 dark:text-gray-300">
            Data {isJson && <span className="text-xs text-gray-500">(JSON)</span>}:
          </div>
          <div className="rounded border border-gray-200 bg-gray-50 p-3 dark:border-gray-600 dark:bg-gray-700">
            {isJson ? (
              <Json json={parsed} initialCollapsed="expanded" />
            ) : (
              <pre className="whitespace-pre-wrap text-sm text-gray-800 dark:text-gray-200">
                {String(parsed)}
              </pre>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export const EventStreamComposer: React.FC<IProps> = ({ content }) => {
  const events = React.useMemo(() => parseEventStream(content || ''), [content])
  const [mode, setMode] = React.useState<number>(EventStreamModeEnum.VIEW)
  const [activeEventIndex, setActiveEventIndex] = React.useState<number | null>(null)
  const contentContainerRef = React.useRef<HTMLDivElement | null>(null)

  const showView: boolean = mode === 0 || (mode & EventStreamModeEnum.VIEW) !== 0
  const showNavigation: boolean = (mode & EventStreamModeEnum.NAVIGATION) !== 0
  const columns: number = (showView ? 1 : 0) + (showNavigation ? 1 : 0)

  const scrollToEvent = React.useCallback((index: number) => {
    const container = contentContainerRef.current
    if (!container) return

    const eventCard = container.querySelector(`[data-event-index="${index}"]`) as HTMLElement
    if (eventCard) {
      eventCard.scrollIntoView({ behavior: 'smooth', block: 'start' })
      setActiveEventIndex(index)
    }
  }, [])

  if (!content) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="text-center text-gray-500 dark:text-gray-400">
          <div className="mb-2 text-4xl">📡</div>
          <div>No event stream data to display</div>
        </div>
      </div>
    )
  }

  if (events.length === 0) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="text-center text-gray-500 dark:text-gray-400">
          <div className="mb-2 text-4xl">📡</div>
          <div>No valid events found in stream</div>
        </div>
      </div>
    )
  }

  return (
    <div
      className={cn('flex w-full items-start justify-center', {
        'h-[calc(100vh-7rem)]': columns > 1,
      })}
    >
      {/* Mode Toggle */}
      <div className="fixed right-4 top-16 z-50 flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95">
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
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
            'box-border px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
            showNavigation
              ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => setMode(m => m ^ EventStreamModeEnum.NAVIGATION)}
        >
          nav
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
                <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                  Event Stream
                </h1>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  {events.length} event{events.length !== 1 ? 's' : ''} found
                </p>
              </div>

              <div className="space-y-4">
                {events.map((event, index) => (
                  <div key={`${event.id || index}`} data-event-index={index}>
                    <EventCard event={event} index={index} />
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
