import cn from 'clsx'
import React from 'react'

interface IIslandProps {
  children: React.ReactNode
  className?: string
  padding?: 'sm' | 'md' | 'lg'
}

export const Island: React.FC<IIslandProps> = ({ children, className, padding = 'md' }) => {
  return (
    <div
      className={cn(
        // Base styling matching Excalidraw's Island component with dark theme support
        'relative bg-white/95 dark:bg-gray-800/95 border border-gray-200/60 dark:border-gray-600/60',
        'shadow-sm dark:shadow-gray-900/20', // More subtle shadow like Excalidraw with dark variant
        'rounded-lg', // Excalidraw uses 8px border radius
        'backdrop-blur-sm',
        // Transition for smooth interactions
        'transition-shadow duration-300 ease-in-out',
        {
          'p-1': padding === 'sm',
          'p-2': padding === 'md',
          'p-3': padding === 'lg',
        },
        className,
      )}
      style={
        {
          // CSS variables for potential theming like Excalidraw - updated for dark theme
          '--island-bg-color-light': 'rgba(255, 255, 255, 0.95)',
          '--island-bg-color-dark': 'rgba(31, 41, 55, 0.95)',
          '--island-border-color-light': 'rgba(156, 163, 175, 0.6)',
          '--island-border-color-dark': 'rgba(75, 85, 99, 0.6)',
          '--island-shadow-light':
            '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
          '--island-shadow-dark':
            '0 1px 3px 0 rgba(0, 0, 0, 0.2), 0 1px 2px -1px rgba(0, 0, 0, 0.2)',
        } as React.CSSProperties
      }
    >
      {children}
    </div>
  )
}
