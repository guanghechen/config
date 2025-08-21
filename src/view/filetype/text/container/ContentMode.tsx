import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useTextViewViewModel } from '../context'
import { ContentModeEnum } from '../context/types'

interface IContentModeOption {
  readonly value: ContentModeEnum
  readonly label: string
  readonly icon: React.ReactNode
}

const CONTENT_MODE_OPTIONS: ReadonlyArray<IContentModeOption> = [
  {
    value: ContentModeEnum.ORIGINAL,
    label: 'Original',
    icon: (
      <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
        />
      </svg>
    ),
  },
  {
    value: ContentModeEnum.LIST,
    label: 'List',
    icon: (
      <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M4 6h16M4 10h16M4 14h16M4 18h16"
        />
      </svg>
    ),
  },
  {
    value: ContentModeEnum.GRAPH,
    label: 'Graph',
    icon: (
      <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
        />
      </svg>
    ),
  },
] as const

export const ContentMode: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const transformedNodes = useStateValue(viewmodel.records$)
  const [isOpen, setIsOpen] = React.useState<boolean>(false)
  const dropdownRef = React.useRef<HTMLDivElement>(null)

  const isListDisabled: boolean = !transformedNodes || transformedNodes.length === 0
  const isGraphDisabled: boolean = !transformedNodes || transformedNodes.length === 0
  const actualContentMode: ContentModeEnum =
    (contentMode === ContentModeEnum.LIST && isListDisabled) ||
    (contentMode === ContentModeEnum.GRAPH && isGraphDisabled)
      ? ContentModeEnum.ORIGINAL
      : contentMode

  const currentOption = CONTENT_MODE_OPTIONS.find(option => option.value === contentMode)

  const handleSelect = useEventCallback((mode: ContentModeEnum): void => {
    if (mode === ContentModeEnum.LIST && isListDisabled) {
      return
    }
    if (mode === ContentModeEnum.GRAPH && isGraphDisabled) {
      return
    }
    viewmodel.contentMode$.next(mode)
    setIsOpen(false)
  })

  const handleKeyDown = useEventCallback((event: React.KeyboardEvent): void => {
    if (event.key === 'Escape') {
      setIsOpen(false)
    } else if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      setIsOpen(!isOpen)
    } else if (event.key === 'ArrowDown' && isOpen) {
      event.preventDefault()
      const firstOption = dropdownRef.current?.querySelector('[role="option"]') as HTMLButtonElement
      firstOption?.focus()
    }
  })

  const handleOptionKeyDown = useEventCallback(
    (event: React.KeyboardEvent, mode: ContentModeEnum, index: number): void => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault()
        if (mode === ContentModeEnum.LIST && isListDisabled) {
          return
        }
        if (mode === ContentModeEnum.GRAPH && isGraphDisabled) {
          return
        }
        handleSelect(mode)
      } else if (event.key === 'ArrowDown') {
        event.preventDefault()
        const nextIndex = (index + 1) % CONTENT_MODE_OPTIONS.length
        const nextOption = dropdownRef.current?.querySelectorAll('[role="option"]')[
          nextIndex
        ] as HTMLButtonElement
        nextOption?.focus()
      } else if (event.key === 'ArrowUp') {
        event.preventDefault()
        const prevIndex = index === 0 ? CONTENT_MODE_OPTIONS.length - 1 : index - 1
        const prevOption = dropdownRef.current?.querySelectorAll('[role="option"]')[
          prevIndex
        ] as HTMLButtonElement
        prevOption?.focus()
      } else if (event.key === 'Escape') {
        setIsOpen(false)
      }
    },
  )

  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        onKeyDown={handleKeyDown}
        className="group flex h-8 select-none items-center gap-2 rounded-lg bg-white/80 px-3 py-1.5 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:bg-white/90 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 dark:bg-gray-900/80 dark:hover:bg-gray-900/90 dark:focus:ring-indigo-400/50"
        title={`Content mode: ${currentOption?.label}`}
        aria-expanded={isOpen}
        aria-haspopup="listbox"
        aria-label="Select content mode"
      >
        <div className="flex items-center gap-1.5 text-gray-700 dark:text-gray-300">
          {currentOption?.icon}
          <span className="capitalize">{currentOption?.label}</span>
        </div>
        <svg
          className={cn(
            'h-3.5 w-3.5 text-gray-500 transition-transform duration-200 dark:text-gray-400',
            isOpen ? 'rotate-180' : 'group-hover:text-gray-700 dark:group-hover:text-gray-300',
          )}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div
          className="absolute z-50 left-0 top-full mt-2 min-w-40 overflow-hidden rounded-xl bg-white/95 shadow-2xl backdrop-blur-md ring-1 ring-gray-200/50 dark:bg-gray-900/95 dark:ring-gray-700/50"
          role="listbox"
          aria-label="Content mode options"
        >
          <div className="p-1">
            {CONTENT_MODE_OPTIONS.map((option, index) => {
              const isDisabled =
                (option.value === ContentModeEnum.LIST && isListDisabled) ||
                (option.value === ContentModeEnum.GRAPH && isGraphDisabled)
              return (
                <button
                  key={option.value}
                  onClick={() => !isDisabled && handleSelect(option.value)}
                  onKeyDown={event => handleOptionKeyDown(event, option.value, index)}
                  disabled={isDisabled}
                  className={cn(
                    'group flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm transition-all duration-150 focus:outline-none',
                    isDisabled
                      ? 'cursor-not-allowed opacity-50'
                      : actualContentMode === option.value
                        ? 'bg-indigo-50 text-indigo-700 shadow-sm dark:bg-indigo-900/50 dark:text-indigo-300'
                        : 'text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50',
                  )}
                  role="option"
                  aria-selected={actualContentMode === option.value}
                  aria-disabled={isDisabled}
                  tabIndex={isOpen && !isDisabled ? 0 : -1}
                >
                  <div
                    className={cn(
                      'flex h-6 w-6 items-center justify-center rounded transition-colors',
                      isDisabled
                        ? 'text-gray-400 dark:text-gray-600'
                        : actualContentMode === option.value
                          ? 'text-indigo-600 dark:text-indigo-400'
                          : 'text-gray-500 group-hover:text-gray-700 dark:text-gray-400 dark:group-hover:text-gray-300',
                    )}
                  >
                    {option.icon}
                  </div>
                  <span
                    className={cn('font-medium', isDisabled && 'text-gray-400 dark:text-gray-600')}
                  >
                    {option.label}
                  </span>
                  {actualContentMode === option.value && !isDisabled && (
                    <svg
                      className="ml-auto h-4 w-4 text-indigo-600 dark:text-indigo-400"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                      aria-hidden="true"
                    >
                      <path
                        fillRule="evenodd"
                        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                        clipRule="evenodd"
                      />
                    </svg>
                  )}
                </button>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

ContentMode.displayName = 'TextViewContentMode'
