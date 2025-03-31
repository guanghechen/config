import React from 'react'
import { WorkspaceContextProvider, useWorkspaceViewmodel } from '@/context/workspace'
import { WorkspaceLayout } from './Layout'

export const WorkspaceContainer: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  return <WorkspaceLayout viewmodel={viewmodel} />
}

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceContextProvider>
      <WorkspaceContainer />
    </WorkspaceContextProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
export default WorkspaceView
