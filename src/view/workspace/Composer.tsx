import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileSearch } from './container/FileSearch'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'
import { Topbar } from './layout/topbar'
import { useWorkspaceViewmodel } from './context'

export const Composer: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="f-vf-root">
      <Topbar />
      <FileSearch />
      <div className="f-vf-sidebar">
        <Sidebar />
      </div>
      <Main workspace={workspace} filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
    </div>
  )
}

Composer.displayName = 'WorkspaceViewComposer'
