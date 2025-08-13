import React from 'react'
import { Composer } from './Composer'
import { WorkspaceViewProvider } from './context'

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceViewProvider>
      <Composer />
    </WorkspaceViewProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
