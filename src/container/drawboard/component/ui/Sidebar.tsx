import cn from 'clsx'
import React, { useState } from 'react'

interface ISidebarProps {
  children: React.ReactNode
  side?: 'left' | 'right'
  title?: string
  defaultOpen?: boolean
  width?: number
}

export const Sidebar: React.FC<ISidebarProps> = ({
  children,
  side = 'right',
  title,
  defaultOpen = false,
  width = 280,
}) => {
  const [isOpen, setIsOpen] = useState(defaultOpen)

  return (
    <React.Fragment>
      {/* Sidebar */}
      <div
        className={cn(
          'fixed top-0 z-30 h-full bg-white dark:bg-gray-800 shadow-xl dark:shadow-black/25 border dark:border-gray-600 transition-transform duration-300 ease-in-out',
          {
            'left-0 border-r': side === 'left',
            'right-0 border-l': side === 'right',
            'translate-x-0': isOpen,
            '-translate-x-full': !isOpen && side === 'left',
            'translate-x-full': !isOpen && side === 'right',
          },
        )}
        style={{ width }}
      >
        {/* Header */}
        {title && (
          <div className="flex items-center justify-between border-b dark:border-gray-600 px-4 py-3">
            <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">{title}</h3>
            <button
              onClick={() => setIsOpen(false)}
              className="rounded p-1 text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">{children}</div>
      </div>

      {/* Toggle Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={cn(
          'fixed top-4 z-40 rounded-lg bg-white dark:bg-gray-800 p-2 shadow-lg dark:shadow-black/25 border dark:border-gray-600 transition-transform duration-300',
          {
            'left-4': side === 'left' && !isOpen,
            'right-4': side === 'right' && !isOpen,
            'translate-x-0': !isOpen,
          },
          isOpen && side === 'left' && 'left-4',
          isOpen && side === 'right' && 'right-4',
        )}
        style={{
          transform: isOpen
            ? side === 'left'
              ? `translateX(${width - 48}px)`
              : `translateX(-${width - 48}px)`
            : 'translateX(0)',
        }}
      >
        <svg
          className={cn('h-5 w-5 text-gray-600 dark:text-gray-400 transition-transform', {
            'rotate-180': isOpen && side === 'right',
            'rotate-0': isOpen && side === 'left',
          })}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d={side === 'left' ? 'M9 5l7 7-7 7' : 'M15 19l-7-7 7-7'}
          />
        </svg>
      </button>

      {/* Backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 z-20 bg-black/20 backdrop-blur-sm"
          onClick={() => setIsOpen(false)}
        />
      )}
    </React.Fragment>
  )
}
