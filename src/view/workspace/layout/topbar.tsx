import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/component/FilePath'
import { DockToRightIcon } from '@/component/icon/material'
import { Workspace } from '../container/Workspace'
import { useWorkspaceViewmodel } from '../context'

export const Topbar: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const sidebarVisible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const onToggleBothSidebarAndTopbar = viewmodel.toggleBothSidebarAndTopbar
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  return (
    <div className="f-vf-topbar">
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
        {filepath && <FilePath filepath={filepath} workspace={workspace} />}
      </div>
    </div>
  )
}

Topbar.displayName = 'WorkspaceViewTopbar'
