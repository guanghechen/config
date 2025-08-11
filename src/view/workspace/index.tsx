import React from 'react'
import { WorkspaceContextProvider } from '@/context/workspace'
import { Composer } from './Composer'

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceContextProvider>
      <Composer />
    </WorkspaceContextProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
