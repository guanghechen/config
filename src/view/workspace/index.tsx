import cn from 'clsx'
import React from 'react'
import { WorkspaceContextProvider, useResizing, useWorkspaceViewmodel } from './context'
import { WorkspaceLayout } from './Layout'

export const WorkspaceContaienr: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const resizing: boolean = useResizing()

  return (
    <div className={cn({ 'select-none': resizing })}>
      <WorkspaceLayout viewmodel={viewmodel} />
    </div>
  )
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
