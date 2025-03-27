import React from 'react'
import { DockToRightIcon } from '@/component/icon/material'
import { ThemeToggle } from '@/container/ThemeToggle'
import type { WorkspaceViewModel } from '../context'
import { useSidebarVisible, useToggleSidebarVisible } from '../context'
import { Workspace } from '../sidebar/Workspace'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceTopbar: React.FC<IProps> = () => {
  const sidebarVisible: boolean = useSidebarVisible()
  const onToggleSidebarVisible: () => void = useToggleSidebarVisible()

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
      <div className="flex-initial">
        <ThemeToggle />
      </div>
    </div>
  )
}

WorkspaceTopbar.displayName = 'WorkspaceTopbar'
export default WorkspaceTopbar
