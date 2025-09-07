import cn from 'clsx'
import React from 'react'

interface IToolButtonProps {
  icon: React.ComponentType<{ className?: string }>
  label: string
  isActive?: boolean
  onClick: () => void
  shortcut?: string
  disabled?: boolean
  variant?: 'primary' | 'secondary' | 'danger'
  size?: 'small' | 'medium' | 'large'
  isLoading?: boolean
  'aria-label'?: string
  'aria-keyshortcuts'?: string
  keyBindingLabel?: string | null
  numericKey?: string
}

export const ToolButton: React.FC<IToolButtonProps> = ({
  icon: Icon,
  label,
  isActive = false,
  onClick,
  shortcut,
  disabled = false,
  variant = 'primary',
  size = 'medium',
  isLoading = false,
  'aria-label': ariaLabel,
  'aria-keyshortcuts': ariaKeyshortcuts,
  keyBindingLabel,
  numericKey,
}) => {
  const sizeClasses = {
    small: 'h-6 w-6', // 24px - compact
    medium: 'h-8 w-8', // 32px - Excalidraw default
    large: 'h-10 w-10', // 40px - larger
  }

  const iconSizes = {
    small: 'h-3 w-3', // 12px
    medium: 'h-4 w-4', // 16px - Excalidraw standard
    large: 'h-5 w-5', // 20px
  }

  const displayShortcut = keyBindingLabel || shortcut

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || isLoading}
      aria-label={ariaLabel || label}
      aria-keyshortcuts={ariaKeyshortcuts || shortcut}
      aria-pressed={isActive}
      className={cn(
        'group relative flex items-center justify-center rounded-md',
        'transition-colors duration-75 ease-out',
        'focus:outline-none focus:ring-2 focus:ring-blue-400/30 dark:focus:ring-blue-500/40 focus:ring-offset-1 dark:focus:ring-offset-gray-800',
        sizeClasses[size],
        {
          // Active states - blue background with proper contrast for dark theme
          'bg-blue-500/90 text-white dark:bg-blue-600/90': isActive && variant === 'primary',
          'bg-gray-700 text-white dark:bg-gray-600 dark:text-gray-100':
            isActive && variant === 'secondary',
          'bg-red-500/90 text-white dark:bg-red-600/90': isActive && variant === 'danger',

          // Inactive states - very subtle hover with dark theme support
          'text-gray-600 dark:text-gray-300 hover:bg-gray-100/70 dark:hover:bg-gray-700/50':
            !isActive && !disabled && variant === 'primary',
          'text-gray-500 dark:text-gray-400 hover:bg-gray-50/70 dark:hover:bg-gray-600/50':
            !isActive && !disabled && variant === 'secondary',
          'text-red-500 dark:text-red-400 hover:bg-red-50/70 dark:hover:bg-red-900/30':
            !isActive && !disabled && variant === 'danger',

          // Disabled state
          'text-gray-300 dark:text-gray-600 cursor-not-allowed': disabled,
          'opacity-50': isLoading,
        },
      )}
      title={displayShortcut ? `${label} (${displayShortcut})` : label}
    >
      {isLoading ? (
        <div
          className={cn(
            'animate-spin rounded-full border border-gray-300 border-t-blue-500',
            iconSizes[size],
          )}
        />
      ) : (
        <Icon
          className={cn(iconSizes[size], 'flex-shrink-0', {
            'stroke-black dark:stroke-white': isActive && variant === 'primary',
          })}
        />
      )}

      {numericKey && (
        <span className="absolute bottom-0.5 right-0.5 text-[10px] text-gray-800 dark:text-gray-200 font-normal leading-none select-none">
          {numericKey}
        </span>
      )}

      {/* Tooltip matching Excalidraw's style with dark theme support */}
      <div className="absolute top-full mt-3 left-1/2 -translate-x-1/2 z-50 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-150 delay-500">
        <div className="rounded-md bg-gray-800 dark:bg-gray-900 px-2 py-1.5 text-xs text-white dark:text-gray-100 whitespace-nowrap shadow-lg dark:shadow-black/50">
          <div className="font-medium">{label}</div>
          {displayShortcut && !numericKey && (
            <div className="text-gray-300 dark:text-gray-400 mt-0.5 text-[10px]">
              {displayShortcut}
            </div>
          )}
          {/* Tooltip arrow */}
          <div className="absolute bottom-full left-1/2 -translate-x-1/2 border-4 border-transparent border-b-gray-800 dark:border-b-gray-900" />
        </div>
      </div>
    </button>
  )
}

interface IToolSeparatorProps {
  orientation?: 'horizontal' | 'vertical'
}

export const ToolSeparator: React.FC<IToolSeparatorProps> = ({ orientation = 'horizontal' }) => {
  return (
    <div
      className={cn('bg-gray-200/80 dark:bg-gray-600/60', {
        'my-2 h-px w-full': orientation === 'horizontal',
        'mx-2 w-px h-6': orientation === 'vertical',
      })}
    />
  )
}
