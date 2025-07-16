import cn from 'clsx'
import React from 'react'
import { useLocation, useNavigate } from 'react-router-dom'

interface RouteItem {
  path: string
  label: string
  icon?: React.ReactNode
}

const routes: RouteItem[] = [
  { path: '/', label: 'Workspace' },
  { path: '/playground/excalidraw', label: 'Excalidraw' },
]

export const RouteNavigation: React.FC = () => {
  const location = useLocation()
  const navigate = useNavigate()

  const handleNavigation = (path: string): void => {
    void navigate(path)
  }

  return (
    <div className="flex items-center gap-1">
      {routes.map(route => {
        const isActive =
          location.pathname === route.path ||
          (route.path === '/' && location.pathname === '/workspace/')
        return (
          <button
            key={route.path}
            onClick={() => handleNavigation(route.path)}
            className={cn(
              'rounded-lg px-3 py-1.5 text-sm font-medium transition-colors',
              'hover:bg-gray-100 dark:hover:bg-gray-700',
              'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50',
              isActive
                ? 'bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300'
                : 'text-gray-600 dark:text-gray-400',
            )}
            title={`Navigate to ${route.label}`}
          >
            {route.icon && <span className="mr-1">{route.icon}</span>}
            {route.label}
          </button>
        )
      })}
    </div>
  )
}
