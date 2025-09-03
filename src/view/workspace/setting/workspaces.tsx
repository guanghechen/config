import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useNavigate } from 'react-router-dom'
import { ChevronRightIcon, ViewStreamIcon } from '@/component/icon/material'
import { useWorkspaceViewmodel } from '../context'

export const WorkspaceSelector: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const currentWorkspace = useStateValue(viewmodel.workspace$)
  const workspaces = useStateValue(viewmodel.workspaces$)
  const navigate = useNavigate()

  const [isOpen, setIsOpen] = React.useState(false)

  const handleWorkspaceSelect = React.useCallback(
    (workspaceTag: string): void => {
      setIsOpen(false)
      viewmodel.workspace$.next(workspaceTag)
      void navigate(`/ws/${workspaceTag}`)
    },
    [viewmodel, navigate],
  )

  const handleToggle = React.useCallback((e: React.MouseEvent): void => {
    e.preventDefault()
    e.stopPropagation()
    setIsOpen(prev => !prev)
  }, [])

  // Get current workspace display name - use "default" as fallback
  const effectiveCurrentWorkspace = currentWorkspace || 'default'

  return (
    <div className="relative">
      <button
        onClick={handleToggle}
        className={cn(
          'flex items-center px-4 py-3 rounded-md w-full leading-relaxed',
          'transition-colors duration-150 ease-in-out',
          'focus:outline-none',
          'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
          'hover:bg-gray-100 dark:hover:bg-gray-700',
        )}
        title="Select workspace"
      >
        <div className="flex items-center gap-3 flex-1">
          <ViewStreamIcon className="h-4 w-4 flex-shrink-0" />
          <span className="text-sm text-gray-700 dark:text-gray-200 truncate">
            {effectiveCurrentWorkspace}
          </span>
        </div>
        <ChevronRightIcon
          className={cn('h-4 w-4 flex-shrink-0 transition-transform duration-150')}
        />
      </button>

      {isOpen && (
        <React.Fragment>
          <div className="absolute top-0 left-full ml-1 w-48 bg-white dark:bg-gray-800 rounded-md border border-gray-200 dark:border-gray-600 shadow-lg z-50 max-h-48 overflow-y-auto">
            {/* Default workspace as regular option */}
            <button
              onClick={() => handleWorkspaceSelect('default')}
              className={cn(
                'w-full text-left px-4 py-3 text-sm leading-relaxed hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center gap-3 transition-colors duration-150',
                effectiveCurrentWorkspace === 'default'
                  ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                  : 'text-gray-700 dark:text-gray-300',
              )}
            >
              <ViewStreamIcon className="h-4 w-4 flex-shrink-0" />
              <span className="truncate">default</span>
            </button>
            {workspaces
              .filter(workspace => workspace.tag !== 'default')
              .map(workspace => (
                <button
                  key={workspace.tag}
                  onClick={() => handleWorkspaceSelect(workspace.tag)}
                  className={cn(
                    'w-full text-left px-4 py-3 text-sm leading-relaxed hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center gap-3 transition-colors duration-150',
                    workspace.tag === effectiveCurrentWorkspace
                      ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                      : 'text-gray-700 dark:text-gray-300',
                  )}
                >
                  <ViewStreamIcon className="h-4 w-4 flex-shrink-0" />
                  <span className="truncate">{workspace.tag}</span>
                </button>
              ))}
          </div>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
        </React.Fragment>
      )}
    </div>
  )
}

WorkspaceSelector.displayName = 'WorkspaceViewWorkspaceSelector'
