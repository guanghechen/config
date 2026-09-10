import cn from '@/common/util/clsx'
import React from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { ChevronRightIcon, FolderIcon, SettingsIcon } from '@/common/component/icon/material'
import { ThemeToggle } from './ThemeToggle'

interface IProps {
  readonly additionalItems?: React.ReactElement
}

export const Settings: React.FC<IProps> = ({ additionalItems }) => {
  const [isOpen, setIsOpen] = React.useState(false)
  const rootRef = React.useRef<HTMLDivElement>(null)
  const panelRef = React.useRef<HTMLDivElement>(null)
  const triggerRef = React.useRef<HTMLButtonElement>(null)
  const panelId = React.useId()
  const location = useLocation()
  const navigate = useNavigate()
  const isWorkspace = location.pathname === '/ws' || location.pathname.startsWith('/ws/')

  React.useLayoutEffect(() => {
    if (isOpen) panelRef.current?.querySelector<HTMLInputElement>('input:checked')?.focus()
  }, [isOpen])

  React.useEffect(() => {
    if (!isOpen) return
    const onPointerDown = (event: PointerEvent): void => {
      if (event.target instanceof Node && !rootRef.current?.contains(event.target)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('pointerdown', onPointerDown)
    return () => document.removeEventListener('pointerdown', onPointerDown)
  }, [isOpen])

  return (
    <div
      ref={rootRef}
      className="relative font-sans"
      onKeyDown={event => {
        if (event.key === 'Escape' && isOpen) {
          event.preventDefault()
          event.stopPropagation()
          setIsOpen(false)
          triggerRef.current?.focus()
        }
      }}
      onBlur={event => {
        if (
          event.relatedTarget instanceof Node &&
          !event.currentTarget.contains(event.relatedTarget)
        ) {
          setIsOpen(false)
        }
      }}
    >
      <button
        ref={triggerRef}
        type="button"
        aria-label="Settings"
        aria-haspopup="dialog"
        aria-expanded={isOpen}
        aria-controls={isOpen ? panelId : undefined}
        onClick={() => setIsOpen(open => !open)}
        className={cn(
          'flex h-8 w-8 items-center justify-center rounded-lg transition-colors',
          'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500',
          isOpen
            ? 'bg-gray-200/70 text-gray-900 dark:bg-gray-700 dark:text-white'
            : 'text-gray-500 hover:bg-gray-200/60 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white',
        )}
        title="Settings"
      >
        <SettingsIcon className="h-4 w-4" />
      </button>
      {isOpen && (
        <div
          ref={panelRef}
          id={panelId}
          role="dialog"
          aria-label="Settings"
          className="absolute left-0 top-full z-50 mt-2 w-60 max-w-[calc(100vw-2rem)] rounded-xl border border-gray-200 bg-white p-2 shadow-lg shadow-black/5 dark:border-gray-700 dark:bg-gray-900 dark:shadow-black/20"
        >
          <div className="px-2 py-2 text-sm font-semibold text-gray-900 dark:text-gray-100">
            Settings
          </div>
          <ThemeToggle />
          {additionalItems && (
            <div className="mt-2 border-t border-gray-100 pt-2 dark:border-gray-800">
              {additionalItems}
            </div>
          )}
          <div className="mt-2 border-t border-gray-100 pt-2 dark:border-gray-800">
            <button
              type="button"
              onClick={() => {
                setIsOpen(false)
                triggerRef.current?.focus()
                void navigate(isWorkspace ? `${location.pathname}${location.search}` : '/ws')
              }}
              className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-gray-600 transition-colors hover:bg-gray-100 focus-visible:outline-2 focus-visible:outline-blue-500 dark:text-gray-300 dark:hover:bg-gray-800"
            >
              <FolderIcon className="h-4 w-4 shrink-0" />
              <span className="flex-1 text-left">Workspace</span>
              <ChevronRightIcon className="h-3.5 w-3.5 text-gray-400" />
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

Settings.displayName = 'Settings'
