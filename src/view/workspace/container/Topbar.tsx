import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { AnchorButton } from '@/component/button/anchor'
import { CopyButton } from '@/component/button/copy'
import { DockToRightIcon } from '@/component/icon/material'
import { useWorkspaceViewmodel } from '../context'
import { Workspace } from './sidebar/Workspace'

export const Topbar: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const sidebarVisible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const onToggleBothSidebarAndTopbar = viewmodel.toggleBothSidebarAndTopbar
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  return (
    <div className="flex h-full items-center text-slate-800 px-4 dark:text-gray-200">
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
      {filepath && (
        <div className="flex flex-initial items-center gap-1">
          <h2 className="pointer-events-none select-none truncate font-mono text-sm font-medium text-gray-700 dark:text-gray-300">
            {filepath}
          </h2>
          <AnchorButton workspace={workspace} filepath={filepath} />
          <CopyButton
            className="rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700 focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors"
            calcContentForCopy={() => filepath || ''}
          />
        </div>
      )}
    </div>
  )
}

Topbar.displayName = 'WorkspaceTopbar'
