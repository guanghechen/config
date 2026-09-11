import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/common/component/FilePath'
import cn from '@/common/util/clsx'
import { relativeWorkspaceFilepath } from '@/common/util/path'
import { useWorkspaceViewmodel } from '../context'
import { WorkspaceSelector } from '../setting/workspaces'

export const Menu: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspaceRoot: string | null = useStateValue(viewmodel.workspaceRoot$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)
  const sidebarVisible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const sidebarToggleLabel = sidebarVisible ? 'Hide sidebar' : 'Show sidebar'

  return (
    <div className="flex h-full min-w-0 items-center gap-1 text-slate-800 dark:text-gray-200">
      <button
        type="button"
        title={sidebarToggleLabel}
        aria-label={sidebarToggleLabel}
        aria-expanded={sidebarVisible}
        onClick={() => viewmodel.sidebarVisible$.next(!sidebarVisible)}
        className={cn(
          'flex h-8 w-8 shrink-0 items-center justify-center rounded-lg transition-colors',
          'text-gray-500 hover:bg-gray-200/60 hover:text-gray-900',
          'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500',
          'dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white',
        )}
      >
        <SidebarIcon className="h-4 w-4" expanded={sidebarVisible} />
      </button>
      <WorkspaceSelector />
      <a
        href="/whiteboard"
        className="ml-2 rounded-lg px-3 py-1 text-sm hover:bg-gray-200/60 dark:hover:bg-gray-700"
      >
        Whiteboard
      </a>
      {filepath && (
        <React.Fragment>
          <span
            aria-hidden="true"
            className="mx-3 h-5 w-px shrink-0 bg-gray-300 dark:bg-gray-600"
          />
          <FilePath
            filepath={filepath}
            displayFilepath={
              workspaceRoot ? relativeWorkspaceFilepath(filepath, workspaceRoot) : filepath
            }
          />
        </React.Fragment>
      )}
    </div>
  )
}

Menu.displayName = 'WorkspaceViewMenu'

const SidebarIcon: React.FC<{
  readonly className?: string
  readonly expanded: boolean
}> = ({ className, expanded }) => (
  <svg
    aria-hidden="true"
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.8"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <rect x="3" y="4" width="18" height="16" rx="2" />
    <path d="M9 4v16" />
    {expanded && <path d="M5.5 7h1" strokeWidth="2.2" />}
  </svg>
)
SidebarIcon.displayName = 'WorkspaceSidebarIcon'
