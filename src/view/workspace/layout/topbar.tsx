import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/component/FilePath'
import { Workspace } from '../container/Workspace'
import { useWorkspaceViewmodel } from '../context'

export const Topbar: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  return (
    <div className="flex h-full items-center text-slate-800 px-4 dark:text-gray-200">
      <div className="box-border flex flex-initial justify-center gap-4">
        <Workspace />
      </div>
      {filepath && <FilePath filepath={filepath} workspace={workspace} />}
    </div>
  )
}

Topbar.displayName = 'WorkspaceViewTopbar'
