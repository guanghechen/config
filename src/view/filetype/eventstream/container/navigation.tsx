import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import type { IEventStreamEvent } from '../utils'

interface IProps {
  readonly events: IEventStreamEvent[]
  readonly singleColumn: boolean
  readonly activeEventIndex: number | null
  readonly onEventClick: (index: number) => void
}

export const EventStreamNavigation: React.FC<IProps> = ({
  events,
  singleColumn,
  onEventClick,
  activeEventIndex,
}) => {
  return (
    <div
      className={cn(
        'flex-auto basis-0 border-4 border-transparent backdrop-blur-md backdrop-saturate-150 bg-white/70 rounded-lg shadow-lg text-slate-800 dark:bg-gray-800/60 dark:text-gray-200',
        {
          'overflow-auto h-full': !singleColumn,
          [PRESET_CLASSES.scrollbar]: !singleColumn,
          'flex justify-center': singleColumn,
        },
      )}
    >
      <div className="p-4">
        <h3 className="mb-4 p-0 m-0 text-lg font-medium text-gray-800 dark:text-gray-100">
          Events ({events.length})
        </h3>
        <div className="space-y-2">
          {events.map((event, index) => (
            <button
              key={`nav-event-${event.id || index}`}
              onClick={() => onEventClick(index)}
              className={cn(
                'w-full rounded-lg border p-3 text-left text-sm transition-all duration-200 hover:bg-gray-50 dark:hover:bg-gray-700',
                activeEventIndex === index
                  ? 'border-blue-500 bg-blue-50 dark:border-blue-400 dark:bg-blue-900/30'
                  : 'border-gray-200 dark:border-gray-600',
              )}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-800 dark:bg-blue-900 dark:text-blue-300">
                    #{index + 1}
                  </span>
                  {event.event && (
                    <span className="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-300">
                      {event.event}
                    </span>
                  )}
                </div>
                {event.id && (
                  <span className="text-xs text-gray-500 dark:text-gray-400">ID: {event.id}</span>
                )}
              </div>
              {event.data && (
                <div className="mt-2 truncate text-xs text-gray-600 dark:text-gray-300">
                  {event.data.length > 60 ? `${event.data.slice(0, 60)}...` : event.data}
                </div>
              )}
              {event.retry && (
                <div className="mt-1 text-xs text-orange-600 dark:text-orange-400">
                  Retry: {event.retry}ms
                </div>
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}

EventStreamNavigation.displayName = 'EventStreamNavigation'
