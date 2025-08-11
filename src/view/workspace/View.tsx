import React from 'react'
import { Composer } from './Composer'
import { WorkspaceContextProvider } from './context'

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceContextProvider>
      <Composer />
    </WorkspaceContextProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
