import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { CheckIcon, MenuIcon } from '@/component/icon/material'
import { useWorkspaceViewmodel } from '../context'

export const FiletreeToggler: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const sidebarVisible = useStateValue(viewmodel.sidebarVisible$)

  const handleClick = React.useCallback(
    (e: React.MouseEvent): void => {
      e.preventDefault()
      e.stopPropagation()
      viewmodel.sidebarVisible$.updateState(v => !v)
    },
    [viewmodel],
  )

  return (
    <button
      onClick={handleClick}
      className={cn(
        'flex items-center px-4 py-3 rounded-md w-full leading-relaxed',
        'transition-colors duration-150 ease-in-out',
        'focus:outline-none',
        'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        'hover:bg-gray-100 dark:hover:bg-gray-700',
      )}
      title={sidebarVisible ? 'Hide file tree' : 'Show file tree'}
    >
      <div className="flex items-center gap-3 flex-1">
        <MenuIcon className="h-4 w-4 flex-shrink-0" />
        <span className="text-sm text-gray-700 dark:text-gray-200">File Tree</span>
      </div>
      {sidebarVisible && <CheckIcon className="h-4 w-4 flex-shrink-0" />}
    </button>
  )
}

FiletreeToggler.displayName = 'WorkspaceViewFiletreeToggler'
