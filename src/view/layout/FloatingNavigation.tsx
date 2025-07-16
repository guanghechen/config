import cn from 'clsx'
import React, { useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { ThemeToggle } from '@/container/ThemeToggle'

interface RouteItem {
  path: string
  label: string
  icon?: React.ReactNode
}

const routes: RouteItem[] = [
  { path: '/', label: 'Workspace' },
  { path: '/playground/excalidraw', label: 'Excalidraw' },
]

export const FloatingNavigation: React.FC = () => {
  const [isExpanded, setIsExpanded] = useState(false)

  const location = useLocation()
  const navigate = useNavigate()
  const buttonRef = useRef<HTMLButtonElement>(null)

  const handleNavigation = (path: string): void => {
    void navigate(path)
    setIsExpanded(false) // Collapse after navigation
  }

  const toggleExpanded = (): void => {
    setIsExpanded(!isExpanded)
  }

  return (
    <div className="fixed z-50 group bottom-12 right-12">
      <div
        className={cn(
          'absolute right-14 bottom-0 flex flex-col gap-2 transition-all duration-300 ease-in-out',
          'opacity-30 group-hover:opacity-100',
          isExpanded
            ? 'max-h-96 pointer-events-auto'
            : 'max-h-0 overflow-hidden pointer-events-none',
        )}
      >
        {/* Route Navigation Buttons */}
        {routes.map(route => {
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

        {/* Theme Toggle */}
        <div
          className={cn(
            'flex items-center justify-center rounded-lg px-2 py-2 shadow-lg backdrop-blur-md',
            'border border-white/20 transition-all duration-200',
            'bg-white/90 hover:bg-white dark:bg-gray-800/90 dark:hover:bg-gray-700/90',
            'hover:scale-105 hover:shadow-xl',
          )}
        >
          <div className="[&>div]:ml-0">
            <ThemeToggle />
          </div>
        </div>
      </div>

      {/* Toggle Button */}
      <button
        ref={buttonRef}
        onClick={toggleExpanded}
        className={cn(
          'flex h-12 w-12 items-center justify-center rounded-full shadow-lg backdrop-blur-md',
          'border border-white/20 transition-all duration-200',
          'hover:scale-110 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
          'bg-blue-500/90 text-white hover:bg-blue-600/90',
          'opacity-30 group-hover:opacity-100',
        )}
        title={isExpanded ? 'Hide navigation' : 'Show navigation'}
      >
        <svg
          className={cn(
            'h-6 w-6 transition-transform duration-300',
            isExpanded ? 'rotate-45' : 'rotate-0',
          )}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          {isExpanded ? (
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

FloatingNavigation.displayName = 'FloatingNavigation'
