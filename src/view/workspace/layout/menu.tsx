import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/component/FilePath'
import { useWorkspaceViewmodel } from '../context'

export const Menu: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  return (
    <div className="flex h-full items-center text-slate-800 px-4 dark:text-gray-200">
      {filepath && <FilePath filepath={filepath} workspace={workspace} />}
    </div>
  )
}

Menu.displayName = 'WorkspaceViewMenu'
