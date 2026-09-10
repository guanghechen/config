import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/common/component/FilePath'
import { MenuIcon } from '@/common/component/icon/material'
import cn from '@/common/util/clsx'
import { relativeWorkspaceFilepath } from '@/common/util/path'
import { useWorkspaceViewmodel } from '../context'

export const Menu: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspaceRoot: string | null = useStateValue(viewmodel.workspaceRoot$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)
  const sidebarVisible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const sidebarToggleLabel = sidebarVisible ? 'Hide sidebar' : 'Show sidebar'

  return (
    <div className="flex h-full items-center gap-2 px-4 text-slate-800 dark:text-gray-200">
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
        <MenuIcon
          className={cn('h-4 w-4 transition-transform', { 'rotate-180': !sidebarVisible })}
        />
      </button>
      {filepath && (
        <FilePath
          filepath={filepath}
          displayFilepath={
            workspaceRoot ? relativeWorkspaceFilepath(filepath, workspaceRoot) : filepath
          }
        />
      )}
    </div>
  )
}

Menu.displayName = 'WorkspaceViewMenu'
