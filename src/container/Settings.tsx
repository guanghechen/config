import { useEventCallback } from '@guanghechen/react-hooks'
import cn from 'clsx'
import React from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { SettingsIcon } from '@/component/icon/material'
import { listedRoutes } from '@/route'
import { ThemeToggle } from './ThemeToggle'

enum MenuState {
  CLOSED = 'closed',
  OPEN = 'open',
}

interface IProps {
  readonly additionalItems?: React.ReactElement
}

export const Settings: React.FC<IProps> = props => {
  const { additionalItems } = props
  const [menuState, setMenuState] = React.useState<MenuState>(MenuState.CLOSED)

  const location = useLocation()
  const navigate = useNavigate()
  const menuRef = React.useRef<HTMLDivElement>(null)
  const settingsButtonRef = React.useRef<HTMLButtonElement>(null)

  const handleNavigation = useEventCallback((path: string): void => {
    void navigate(path)
    setMenuState(MenuState.CLOSED)
  })

  const toggleMenu = useEventCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    setMenuState(menuState === MenuState.CLOSED ? MenuState.OPEN : MenuState.CLOSED)
  })

  React.useEffect(() => {
    const handleDocumentClick = (event: MouseEvent): void => {
      if (menuState === MenuState.CLOSED) return

      const target = event.target as Node
      const menu = menuRef.current
      const button = settingsButtonRef.current
      if (menu && button && !menu.contains(target) && !button.contains(target)) {
        setMenuState(MenuState.CLOSED)
      }
    }

    if (menuState === MenuState.OPEN) {
      document.addEventListener('click', handleDocumentClick)
    }

    return () => {
      document.removeEventListener('click', handleDocumentClick)
    }
  }, [menuState])

  return (
    <div className="relative">
      <button
        ref={settingsButtonRef}
        onClick={toggleMenu}
        className={cn(
          'flex h-7 w-7 items-center justify-center rounded-full',
          'transition-all duration-300 ease-in-out',
          'hover:scale-105 focus:outline-none',
          'text-gray-700 hover:text-gray-900 dark:text-gray-200 dark:hover:text-gray-100',
          'bg-white/80 hover:bg-white dark:bg-gray-600/90 dark:hover:bg-gray-600',
          'backdrop-blur-sm border border-gray-200/50 dark:border-gray-500/60',
          'shadow-sm hover:shadow-md',
        )}
        title="Settings"
      >
        <div
          className={cn(
            'transition-transform duration-300 ease-in-out',
            menuState === MenuState.OPEN && 'rotate-90',
          )}
        >
          <SettingsIcon className="h-4 w-4" />
        </div>
      </button>
      {menuState === MenuState.OPEN && (
        <div
          ref={menuRef}
          className={cn(
            'absolute left-0 top-9 w-64 rounded-lg shadow-xl',
            'border border-white/20 bg-white dark:bg-gray-800',
            'animate-in fade-in slide-in-from-top-2 duration-200',
          )}
        >
          <div className="p-3">
            {additionalItems && (
              <React.Fragment>
                <div className="mb-4">{additionalItems}</div>
                <div className="my-3 border-b border-gray-200 dark:border-gray-600" />
              </React.Fragment>
            )}
            <div className="mb-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-700 dark:text-gray-200">Theme</span>
                <ThemeToggle />
              </div>
            </div>
            <div className="my-3 border-b border-gray-200 dark:border-gray-600" />
            <div className="space-y-0.5">
              {listedRoutes.map(route => {
                const isActive =
                  location.pathname === route.path ||
                  (route.path === '/' && location.pathname === '/workspace/')

                return (
                  <button
                    key={route.path}
                    onClick={() => handleNavigation(route.path)}
                    className={cn(
                      'flex w-full items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-sm transition-colors',
                      isActive
                        ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300'
                        : 'text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-700',
                    )}
                  >
                    {route.icon && <span className="text-base">{route.icon}</span>}
                    <span>{route.label}</span>
                  </button>
                )
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

Settings.displayName = 'Settings'
