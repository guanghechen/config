import cn from 'clsx'
import React, { useCallback, useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { ThemeToggle } from '@/container/ThemeToggle'

interface RouteItem {
  path: string
  label: string
  icon?: React.ReactNode
}

interface Position {
  x: number
  y: number
}

const routes: RouteItem[] = [
  { path: '/', label: 'Workspace' },
  { path: '/playground/excalidraw', label: 'Excalidraw' },
]

const STORAGE_KEY = 'floating-nav-position'
const DEFAULT_POSITION: Position = { x: 24, y: 24 } // 24px from bottom-right

export const FloatingNavigation: React.FC = () => {
  const [isExpanded, setIsExpanded] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const [position, setPosition] = useState<Position>(DEFAULT_POSITION)
  const [dragOffset, setDragOffset] = useState<Position>({ x: 0, y: 0 })

  const location = useLocation()
  const navigate = useNavigate()
  const buttonRef = useRef<HTMLButtonElement>(null)

  // Load position from localStorage on mount
  useEffect(() => {
    const savedPosition = localStorage.getItem(STORAGE_KEY)
    if (savedPosition) {
      try {
        const parsed = JSON.parse(savedPosition) as Position
        setPosition(parsed)
      } catch {
        // If parsing fails, use default position
        setPosition(DEFAULT_POSITION)
      }
    }
  }, [])

  // Save position to localStorage whenever it changes
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(position))
  }, [position])

  // Constrain position to viewport bounds
  const constrainPosition = useCallback((newPosition: Position): Position => {
    const buttonSize = 48 // 12 * 4 (w-12 h-12)
    const padding = 8

    return {
      x: Math.max(padding, Math.min(window.innerWidth - buttonSize - padding, newPosition.x)),
      y: Math.max(padding, Math.min(window.innerHeight - buttonSize - padding, newPosition.y)),
    }
  }, [])

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    // Prevent click event when starting drag
    e.preventDefault()
    e.stopPropagation()

    if (!buttonRef.current) return

    const rect = buttonRef.current.getBoundingClientRect()
    setDragOffset({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    })
    setIsDragging(true)
  }, [])

  const handleMouseMove = useCallback(
    (e: MouseEvent) => {
      if (!isDragging) return

      const newPosition = constrainPosition({
        x: window.innerWidth - (e.clientX - dragOffset.x) - 48, // Convert to right offset
        y: window.innerHeight - (e.clientY - dragOffset.y) - 48, // Convert to bottom offset
      })

      setPosition(newPosition)
    },
    [isDragging, dragOffset, constrainPosition],
  )

  const handleMouseUp = useCallback(() => {
    setIsDragging(false)
  }, [])

  // Add global mouse listeners for drag
  useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove)
      document.addEventListener('mouseup', handleMouseUp)
      document.body.style.userSelect = 'none' // Prevent text selection while dragging

      return () => {
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
        document.body.style.userSelect = ''
      }
    }
  }, [isDragging, handleMouseMove, handleMouseUp])

  const handleNavigation = (path: string): void => {
    void navigate(path)
    setIsExpanded(false) // Collapse after navigation
  }

  const toggleExpanded = (): void => {
    if (!isDragging) {
      // Only toggle if not dragging
      setIsExpanded(!isExpanded)
    }
  }

  // Handle window resize to reposition if needed
  useEffect(() => {
    const handleResize = () => {
      setPosition(current => constrainPosition(current))
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [constrainPosition])

  return (
    <div
      className="fixed z-50"
      style={{
        right: `${position.x}px`,
        bottom: `${position.y}px`,
      }}
    >
      {/* Floating Navigation Menu */}
      <div
        className={cn(
          'mb-3 flex flex-col gap-2 overflow-hidden transition-all duration-300 ease-in-out',
          isExpanded ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0',
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
                'border border-white/20 transition-all duration-200',
                'hover:scale-105 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
                isActive
                  ? 'bg-blue-500/90 text-white'
                  : 'bg-white/90 text-gray-700 hover:bg-white dark:bg-gray-800/90 dark:text-gray-200 dark:hover:bg-gray-700/90',
              )}
              title={`Navigate to ${route.label}`}
            >
              {route.icon && <span>{route.icon}</span>}
              <span className="whitespace-nowrap">{route.label}</span>
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
        onMouseDown={handleMouseDown}
        className={cn(
          'flex h-12 w-12 items-center justify-center rounded-full shadow-lg backdrop-blur-md',
          'border border-white/20 transition-all duration-200',
          'hover:scale-110 hover:shadow-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500',
          'bg-blue-500/90 text-white hover:bg-blue-600/90',
          isDragging ? 'cursor-grabbing scale-110' : 'cursor-grab',
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
