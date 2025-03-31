import React from 'react'
import { WorkspaceContextProvider, useWorkspaceViewmodel } from '@/context/workspace'
import { WorkspaceLayout } from './Layout'

export const WorkspaceContaienr: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  return <WorkspaceLayout viewmodel={viewmodel} />
}

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceContextProvider>
      <WorkspaceContaienr />
    </WorkspaceContextProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
export default WorkspaceView
