import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useNavigate } from 'react-router-dom'
import type { IWorkspaceItem } from '../context'
import { useWorkspaceViewmodel } from '../context'

export const Workspace: React.FC = () => {
  const viewmodelVM = useWorkspaceViewmodel()
  const currentWorkspace = useStateValue(viewmodelVM.workspace$)
  const workspaces = useStateValue(viewmodelVM.workspaces$)
  const navigate = useNavigate()

  const [isEditing, setIsEditing] = React.useState(false)
  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    const style = document.createElement('style')
    style.textContent = `
      .centered-select option {
        text-align: center;
      }
    `
    document.head.appendChild(style)

    return () => {
      document.head.removeChild(style)
    }
  }, [])

  const onWorkspaceChange = React.useCallback(
    (event: React.ChangeEvent<HTMLSelectElement>): void => {
      const selectedWorkspace = event.target.value
      setIsEditing(false)

      // Navigate to the new workspace route instead of directly setting state
      if (selectedWorkspace) {
        viewmodelVM.workspace$.next(selectedWorkspace)
        void navigate(`/ws/${selectedWorkspace}`)
      } else {
        viewmodelVM.workspace$.next(null)
        void navigate('/ws')
      }
    },
    [viewmodelVM.workspace$, navigate],
  )

  return (
    <div
      ref={containerRef}
      className="relative h-11 cursor-pointer select-none px-4 py-2 text-sm text-gray-700 dark:text-gray-300"
      onMouseEnter={() => setIsEditing(true)}
      onMouseLeave={() => setIsEditing(false)}
    >
      <div className="w-full min-w-[10rem] max-w-[20rem]">
        <select
          className={cn(
            'centered-select w-full rounded-md border border-gray-300 bg-white px-3 py-1 text-center text-sm shadow-xs focus:border-blue-500 focus:outline-hidden dark:border-gray-700 dark:bg-gray-800 dark:text-gray-200',
            { hidden: !isEditing },
          )}
          value={currentWorkspace || ''}
          onChange={onWorkspaceChange}
          autoFocus={true}
        >
          {workspaces.length === 0 && (
            <option value="" disabled={true}>
              No workspace available
            </option>
          )}
          {workspaces.map((workspace: IWorkspaceItem) => (
            <option key={workspace.tag} value={workspace.tag}>
              {workspace.tag}
            </option>
          ))}
        </select>
        <div
          className={cn(
            'rounded-md border border-transparent px-3 py-1 text-center hover:border-gray-400 dark:hover:border-gray-600',
            { hidden: isEditing },
          )}
        >
          {currentWorkspace || 'workspace: null'}
        </div>
      </div>
    </div>
  )
}

Workspace.displayName = 'Workspace'
