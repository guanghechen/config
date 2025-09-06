import cn from 'clsx'
import React, { useEffect, useRef, useState } from 'react'

interface IDropdownItem {
  id: string
  label: string
  icon?: React.ComponentType<{ className?: string }>
  shortcut?: string
  onClick: () => void
  disabled?: boolean
}

interface IDropdownProps {
  trigger: React.ReactNode
  items: IDropdownItem[]
  placement?: 'bottom' | 'top' | 'left' | 'right'
  align?: 'start' | 'center' | 'end'
}

export const Dropdown: React.FC<IDropdownProps> = ({
  trigger,
  items,
  placement = 'bottom',
  align = 'center',
}) => {
  const [isOpen, setIsOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

  const placementClasses = {
    bottom: 'top-full mt-2',
    top: 'bottom-full mb-2',
    left: 'right-full mr-2',
    right: 'left-full ml-2',
  }

  const alignClasses = {
    start: placement === 'bottom' || placement === 'top' ? 'left-0' : 'top-0',
    center:
      placement === 'bottom' || placement === 'top'
        ? 'left-1/2 -translate-x-1/2'
        : 'top-1/2 -translate-y-1/2',
    end: placement === 'bottom' || placement === 'top' ? 'right-0' : 'bottom-0',
  }

  return (
    <div ref={dropdownRef} className="relative">
      <div onClick={() => setIsOpen(!isOpen)}>{trigger}</div>

      {isOpen && (
        <div
          className={cn(
            'absolute z-50 min-w-48',
            'rounded-lg bg-white/95 backdrop-blur-sm',
            'border border-gray-200/50 shadow-xl',
            'ring-1 ring-black/5',
            'py-1',
            placementClasses[placement],
            alignClasses[align],
          )}
        >
          {items.map(item => (
            <button
              key={item.id}
              onClick={() => {
                item.onClick()
                setIsOpen(false)
              }}
              disabled={item.disabled}
              className={cn(
                'w-full flex items-center gap-3 px-3 py-2 text-left',
                'text-sm text-gray-700',
                'hover:bg-gray-100 hover:text-gray-900',
                'disabled:text-gray-400 disabled:cursor-not-allowed',
                'transition-colors duration-150',
              )}
            >
              {item.icon && <item.icon className="h-4 w-4" />}
              <span className="flex-1">{item.label}</span>
              {item.shortcut && (
                <span className="text-xs text-gray-500 font-mono">{item.shortcut}</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
