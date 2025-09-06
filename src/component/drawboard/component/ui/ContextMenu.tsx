import cn from 'clsx'
import React, { useEffect, useRef } from 'react'

export interface IContextMenuItem {
  id: string
  label: string
  icon?: React.ComponentType<{ className?: string }>
  shortcut?: string
  action: () => void
  disabled?: boolean
  separator?: boolean
}

interface IContextMenuProps {
  items: IContextMenuItem[]
  position: { x: number; y: number }
  onClose: () => void
  visible: boolean
}

export const ContextMenu: React.FC<IContextMenuProps> = ({ items, position, onClose, visible }) => {
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    const handleEscape = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    if (visible) {
      document.addEventListener('mousedown', handleClickOutside)
      document.addEventListener('keydown', handleEscape)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
      document.removeEventListener('keydown', handleEscape)
    }
  }, [visible, onClose])

  if (!visible) return null

  return (
    <React.Fragment>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40" />

      {/* Menu */}
      <div
        ref={menuRef}
        className="fixed z-50 min-w-48 rounded-lg bg-white shadow-lg border border-gray-200/50 py-1"
        style={{
          left: position.x,
          top: position.y,
        }}
      >
        {items.map((item, index) => {
          if (item.separator) {
            return <div key={index} className="my-1 border-t border-gray-200" />
          }

          const Icon = item.icon

          return (
            <button
              key={item.id}
              onClick={() => {
                if (!item.disabled) {
                  item.action()
                  onClose()
                }
              }}
              disabled={item.disabled}
              className={cn(
                'flex w-full items-center justify-between px-3 py-2 text-left text-sm',
                'transition-colors hover:bg-gray-100',
                {
                  'text-gray-400 cursor-not-allowed': item.disabled,
                  'text-gray-900': !item.disabled,
                },
              )}
            >
              <div className="flex items-center space-x-2">
                {Icon && <Icon className="h-4 w-4" />}
                <span>{item.label}</span>
              </div>

              {item.shortcut && <span className="text-xs text-gray-500">{item.shortcut}</span>}
            </button>
          )
        })}
      </div>
    </React.Fragment>
  )
}
