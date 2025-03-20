import React from 'react'
import type { WorkspaceViewModel } from './viewmodel'

export interface IWorkspaceContext {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceContextType = React.createContext<IWorkspaceContext>({
  viewmodel: null as unknown as WorkspaceViewModel,
})
WorkspaceContextType.displayName = 'WorkspaceContext'
