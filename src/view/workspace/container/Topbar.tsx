import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { CopyButton } from '@/component/CopyButton'
import { DockToRightIcon, OpenInNewIcon, OpenWithIcon } from '@/component/icon/material'
import { toSearch } from '@/util/url'
import type { WorkspaceViewModel } from '../context'
import { useWorkspaceViewmodel } from '../context'
import { Workspace } from './sidebar/Workspace'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export const Topbar: React.FC<IProps> = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const sidebarVisible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const onToggleBothSidebarAndTopbar = viewmodel.toggleBothSidebarAndTopbar
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  const reveal = React.useCallback(() => {
    viewmodel.revealInSidebar()
  }, [viewmodel])

  return (
    <div className="flex h-full items-center backdrop-blur-md backdrop-saturate-150 bg-white/70 border-b border-white/20 text-slate-800 px-4 dark:bg-gray-800/70 dark:border-gray-700/30 dark:text-gray-200">
      <div className="box-border flex flex-initial justify-center gap-4">
        <button
          onClick={onToggleBothSidebarAndTopbar}
          className="text-gray-600 hover:text-gray-800 focus:outline-hidden dark:text-gray-400 dark:hover:text-gray-200"
          title={sidebarVisible ? 'Hide sidebar and topbar' : 'Show sidebar and topbar'}
        >
          <DockToRightIcon />
        </button>
        <Workspace />
      </div>
      <div className="w-full flex-auto" />
      {filepath && (
        <div className="flex flex-initial items-center gap-1">
          <h2 className="truncate font-mono text-sm font-medium text-gray-700 dark:text-gray-300">
            {filepath}
          </h2>
          <div>
            <span
              className="ml-2 flex items-center justify-center rounded-lg  text-gray-600 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-100"
              onClick={reveal}
            >
              <OpenWithIcon className="size-4" />
            </span>
          </div>
          <div>
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="ml-2 flex items-center justify-center rounded-lg  text-gray-600 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-100"
              title="Open in new tab"
            >
              <OpenInNewIcon className="size-4" />
            </a>
          </div>
          <CopyButton
            className={cn(
              'rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
              'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
              'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            )}
            calcContentForCopy={() => filepath || ''}
          />
        </div>
      )}
    </div>
  )
}

Topbar.displayName = 'WorkspaceTopbar'
