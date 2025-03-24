import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { IWorkspaceItem } from '../context'
import { useWorkspaceViewmodel } from '../context'

export const Workspace: React.FC = () => {
  const viewmodelVM = useWorkspaceViewmodel()
  const currentWorkspace = useStateValue(viewmodelVM.workspace$)
  const workspaces = useStateValue(viewmodelVM.workspaces$)

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
      viewmodelVM.workspace$.setState(() => event.target.value)
      setIsEditing(false)
    },
    [viewmodelVM],
  )

  return (
    <div
      ref={containerRef}
      className="relative h-11 cursor-pointer select-none px-4 py-2 text-sm text-gray-700 dark:text-gray-300"
      onMouseEnter={() => setIsEditing(true)}
      onMouseLeave={() => setIsEditing(false)}
    >
      <div className="w-full min-w-[120px] max-w-[200px]">
        <select
          className={cn(
            'centered-select w-full rounded-md border border-gray-300 bg-white px-3 py-1 text-center text-sm shadow-sm focus:border-blue-500 focus:outline-none dark:border-gray-700 dark:bg-gray-800 dark:text-gray-200',
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
          {currentWorkspace || 'No workspace'}
        </div>
      </div>
    </div>
  )
}
