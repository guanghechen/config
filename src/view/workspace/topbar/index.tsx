import cn from 'clsx'
import React from 'react'
import { CopyButton } from '@/component/CopyButton'
import { DockToRightIcon, OpenInNewIcon, OpenWithIcon } from '@/component/icon/material'
import { ThemeToggle } from '@/container/ThemeToggle'
import { toSearch } from '@/util/url'
import type { WorkspaceViewModel } from '../context'
import {
  useCurrentFilepath,
  useSidebarVisible,
  useToggleSidebarVisible,
  useWorkspace,
  useWorkspaceViewmodel,
} from '../context'
import { Workspace } from '../sidebar/Workspace'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceTopbar: React.FC<IProps> = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useWorkspace()
  const sidebarVisible: boolean = useSidebarVisible()
  const onToggleSidebarVisible: () => void = useToggleSidebarVisible()
  const filepath: string | null = useCurrentFilepath()

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  const reveal = React.useCallback(() => {
    viewmodel.sidebarVisible$.next(true)
    setTimeout(() => {
      viewmodel.revealTick$.next(viewmodel.revealTick$.getSnapshot() + 1)
    }, 50)
  }, [viewmodel])

  return (
    <div className="flex h-full items-center bg-neutral-200 px-4 dark:bg-neutral-800">
      <div className="box-border flex flex-initial justify-center gap-4">
        <button
          onClick={onToggleSidebarVisible}
          className="text-gray-600 hover:text-gray-800 focus:outline-none dark:text-gray-400 dark:hover:text-gray-200"
          title={sidebarVisible ? 'Hide sidebar' : 'Show sidebar'}
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
          <div className="w-28">
            <CopyButton
              className={cn(
                'rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
                'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
              )}
              calcContentForCopy={() => filepath || ''}
            />
          </div>
        </div>
      )}
      <div className="w-full flex-auto" />
      <div className="flex-initial">
        <ThemeToggle />
      </div>
    </div>
  )
}

WorkspaceTopbar.displayName = 'WorkspaceTopbar'
export default WorkspaceTopbar
