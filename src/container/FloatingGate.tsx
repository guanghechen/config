import { useEventCallback } from '@guanghechen/react-hooks'
import cn from 'clsx'
import React, { useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { listedRoutes } from '@/route'
import { ThemeToggle } from './ThemeToggle'

enum MenuLevel {
  CLOSED = 'closed',
  FIRST = 'first',
  NAVIGATION = 'navigation',
  SETTINGS = 'settings',
}

export const FloatingGate: React.FC = () => {
  const [menuLevel, setMenuLevel] = useState<MenuLevel>(MenuLevel.CLOSED)

  const location = useLocation()
  const navigate = useNavigate()
  const buttonRef = useRef<HTMLButtonElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)

  const handleNavigation = useEventCallback((path: string): void => {
    void navigate(path)
    setMenuLevel(MenuLevel.CLOSED) // Close menu after navigation
  })

  const goBackToFirstLevel = useEventCallback((): void => {
    setMenuLevel(MenuLevel.FIRST)
  })

  const showNavigationMenu = useEventCallback((): void => {
    setMenuLevel(MenuLevel.NAVIGATION)
  })

  const showSettingsMenu = useEventCallback((): void => {
    setMenuLevel(MenuLevel.SETTINGS)
  })

  const toggleGate = useEventCallback((): void => {
    setMenuLevel(menuLevel === MenuLevel.CLOSED ? MenuLevel.FIRST : MenuLevel.CLOSED)
  })

  React.useEffect(() => {
    const handleDocumentClick = (event: MouseEvent): void => {
      if (menuLevel === MenuLevel.CLOSED) return

      const target = event.target as Node
      const container = containerRef.current
      const button = buttonRef.current
      if (container && button && !container.contains(target) && !button.contains(target)) {
        setMenuLevel(MenuLevel.CLOSED)
      }
    }

    if (menuLevel !== MenuLevel.CLOSED) {
      document.addEventListener('click', handleDocumentClick)
    }

    return () => {
      document.removeEventListener('click', handleDocumentClick)
    }
  }, [menuLevel])

  return (
    <div ref={containerRef} className="fixed z-50 group bottom-12 right-12">
      <div
        className={cn(
          'absolute right-14 bottom-0 flex flex-col gap-2 transition-all duration-300 ease-in-out',
          'opacity-30 group-hover:opacity-100',
          menuLevel !== MenuLevel.CLOSED
            ? 'max-h-96 pointer-events-auto'
            : 'max-h-0 overflow-hidden pointer-events-none',
        )}
      >
        {menuLevel === MenuLevel.FIRST && (
          <React.Fragment>
            <button
              onClick={showNavigationMenu}
              className={cn(
                'flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-lg backdrop-blur-md',
                'border border-white/20 transition-all duration-200 whitespace-nowrap',
                'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                'bg-white/90 text-gray-700 hover:bg-white dark:bg-gray-800/90 dark:text-gray-200 dark:hover:bg-gray-700/90',
              )}
              title="Navigation"
            >
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 5l7 7-7 7"
                />
              </svg>
              <span>Navigation</span>
            </button>

            {/* Settings Button */}
            <button
              onClick={showSettingsMenu}
              className={cn(
                'flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-lg backdrop-blur-md',
                'border border-white/20 transition-all duration-200 whitespace-nowrap',
                'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                'bg-white/90 text-gray-700 hover:bg-white dark:bg-gray-800/90 dark:text-gray-200 dark:hover:bg-gray-700/90',
              )}
              title="Settings"
            >
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                />
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                />
              </svg>
              <span>Settings</span>
            </button>
          </React.Fragment>
        )}
        {menuLevel === MenuLevel.NAVIGATION && (
          <React.Fragment>
            {/* Back Button */}
            <button
              onClick={goBackToFirstLevel}
              className={cn(
                'flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-lg backdrop-blur-md',
                'border border-white/20 transition-all duration-200 whitespace-nowrap',
                'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                'bg-gray-500/90 text-white hover:bg-gray-600/90',
              )}
              title="Back"
            >
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              <span>Back</span>
            </button>
            {listedRoutes.map(route => {
              const isActive =
                location.pathname === route.path ||
                (route.path === '/' && location.pathname === '/workspace/')

              return (
                <button
                  key={route.path}
                  onClick={() => handleNavigation(route.path)}
                  className={cn(
                    'flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-lg backdrop-blur-md',
                    'border border-white/20 transition-all duration-200 whitespace-nowrap',
                    'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                    isActive
                      ? 'bg-blue-500/90 text-white'
                      : 'bg-white/90 text-gray-700 hover:bg-white dark:bg-gray-800/90 dark:text-gray-200 dark:hover:bg-gray-700/90',
                  )}
                  title={`Navigate to ${route.label}`}
                >
                  {route.icon && <span>{route.icon}</span>}
                  <span>{route.label}</span>
                </button>
              )
            })}
          </React.Fragment>
        )}
        {menuLevel === MenuLevel.SETTINGS && (
          <React.Fragment>
            <button
              onClick={goBackToFirstLevel}
              className={cn(
                'flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-lg backdrop-blur-md',
                'border border-white/20 transition-all duration-200 whitespace-nowrap',
                'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                'bg-gray-500/90 text-white hover:bg-gray-600/90',
              )}
              title="Back"
            >
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              <span>Back</span>
            </button>
            <div
              className={cn(
                'rounded-lg px-4 py-3 shadow-lg backdrop-blur-md',
                'border border-white/20 transition-all duration-200',
                'bg-white/95 dark:bg-gray-800/95',
                'min-w-[200px]',
              )}
            >
              <div className="space-y-3">
                <div className="text-sm font-medium text-gray-700 dark:text-gray-200">Settings</div>
                <div className="space-y-2">
                  <label className="text-xs font-medium text-gray-600 dark:text-gray-300">
                    Theme
                  </label>
                  <div className="flex items-center justify-center">
                    <ThemeToggle />
                  </div>
                </div>
              </div>
            </div>
          </React.Fragment>
        )}
      </div>
      <button
        ref={buttonRef}
        onClick={toggleGate}
        className={cn(
          'flex h-12 w-12 items-center justify-center rounded-full shadow-lg backdrop-blur-md',
          'border border-white/20 transition-all duration-200',
          'hover:scale-110 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
          'bg-blue-500/90 text-white hover:bg-blue-600/90',
          'opacity-30 group-hover:opacity-100',
        )}
        title={menuLevel !== MenuLevel.CLOSED ? 'Close gate' : 'Open gate'}
      >
        <svg
          className={cn(
            'h-6 w-6 transition-transform duration-300',
            menuLevel !== MenuLevel.CLOSED ? 'rotate-45' : 'rotate-0',
          )}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          {menuLevel !== MenuLevel.CLOSED ? (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          ) : (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 6h16M4 12h16M4 18h16"
            />
          )}
        </svg>
      </button>
    </div>
  )
}

FloatingGate.displayName = 'FloatingGate'
