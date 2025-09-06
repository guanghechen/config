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
        // Base styling matching Excalidraw's Island component
        'relative bg-white border border-gray-200/60',
        'shadow-sm', // More subtle shadow like Excalidraw
        'rounded-lg', // Excalidraw uses 8px border radius
        'backdrop-blur-sm bg-white/95',
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
          // CSS variables for potential theming like Excalidraw
          '--island-bg-color': 'rgba(255, 255, 255, 0.95)',
          '--island-border-color': 'rgba(156, 163, 175, 0.6)',
          '--island-shadow': '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
        } as React.CSSProperties
      }
    >
      {children}
    </div>
  )
}
